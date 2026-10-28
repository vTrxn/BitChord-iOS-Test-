import Foundation

/// Specific network error states for user presentation and retry flows.
enum NetworkError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case emptyResponse
    case decodingFailed
    case noAvailableInstance
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The requested URL is invalid."
        case .serverError(let code):
            return "Server responded with status code \(code)."
        case .emptyResponse:
            return "No songs found for this search."
        case .decodingFailed:
            return "Could not parse music data from server."
        case .noAvailableInstance:
            return "All music streaming servers are currently unreachable. Please check your internet connection."
        }
    }
}

/// Handles querying track metadata, trending lists, search suggestions, and catalog searches.
/// Automatically falls back across multiple instances when an endpoint fails or times out.
final class MusicSearchService {
    static let shared = MusicSearchService()
    
    private init() {}
    
    /// Queries the search endpoint for tracks matching the text query.
    /// Iterates through the active and backup instances if the primary node is degraded.
    func searchSongs(query: String) async throws -> [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let primaryInstance = await MainActor.run { InstanceManager.shared.activeInstance }
        let instances = [primaryInstance] + AppConstants.defaultInstances.filter { $0 != primaryInstance }
        
        for instance in instances {
            guard var components = URLComponents(string: "\(instance)/api/v1/search") else { continue }
            components.queryItems = [
                URLQueryItem(name: "q", value: trimmed),
                URLQueryItem(name: "type", value: "video")
            ]
            
            guard let url = components.url else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    continue
                }
                
                let songs = parseSearchItems(from: data)
                if !songs.isEmpty {
                    return songs
                }
            } catch {
                continue
            }
        }
        
        throw NetworkError.noAvailableInstance
    }
    
    /// Fetches real-time autocomplete search suggestions for the user's partial query.
    func fetchSearchSuggestions(query: String) async -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let primaryInstance = await MainActor.run { InstanceManager.shared.activeInstance }
        let instances = [primaryInstance] + AppConstants.defaultInstances.filter { $0 != primaryInstance }
        
        for instance in instances {
            guard var components = URLComponents(string: "\(instance)/api/v1/search/suggestions") else { continue }
            components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            guard let url = components.url else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let suggestions = json["suggestions"] as? [String] else {
                    continue
                }
                return Array(suggestions.prefix(6))
            } catch {
                continue
            }
        }
        return []
    }
    
    /// Fetches currently popular tracks from the server or falls back to a curated chart query.
    func fetchTrending() async throws -> [Song] {
        let primaryInstance = await MainActor.run { InstanceManager.shared.activeInstance }
        let instances = [primaryInstance] + AppConstants.defaultInstances.filter { $0 != primaryInstance }
        
        for instance in instances {
            guard let url = URL(string: "\(instance)/api/v1/popular") else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    continue
                }
                
                let songs = parseSearchItems(from: data)
                if !songs.isEmpty {
                    return songs
                }
            } catch {
                continue
            }
        }
        
        return try await searchSongs(query: "Top Global Hits")
    }
    
    /// Transforms raw Invidious JSON search response into typed Song models.
    private func parseSearchItems(from data: Data) -> [Song] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var results: [Song] = []
        for item in jsonArray {
            guard let videoId = item["videoId"] as? String,
                  !videoId.isEmpty,
                  let rawTitle = item["title"] as? String else {
                continue
            }
            
            let rawAuthor = (item["author"] as? String) ?? "Unknown Artist"
            let lengthSeconds = (item["lengthSeconds"] as? Int) ?? 0
            
            // Always use direct HTTPS YouTube image CDN for reliable, fast thumbnail loading
            let thumbURL = URL(string: "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg")
            
            let cleanedArtist = cleanArtist(rawAuthor)
            let cleanedTitle = cleanTitle(rawTitle, artist: cleanedArtist)
            
            let song = Song(
                id: videoId,
                title: cleanedTitle,
                artist: cleanedArtist,
                durationSeconds: lengthSeconds,
                thumbnailURL: thumbURL,
                albumName: nil
            )
            results.append(song)
        }
        
        return results
    }
    
    /// Strips channel suffixes like "- Topic" or "VEVO" from artist names.
    private func cleanArtist(_ author: String) -> String {
        var cleaned = author
            .replacingOccurrences(of: " - Topic", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "VEVO", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            cleaned = author
        }
        return cleaned
    }
    
    /// Removes boilerplate metadata tags and redundant leading artist prefixes from track titles.
    private func cleanTitle(_ title: String, artist: String) -> String {
        var cleaned = title
        let removablePatterns = [
            #"\s*\(Official (Music |HD |4K |Lyric |Audio )?Video\)"#,
            #"\s*\[Official (Music |HD |4K |Lyric |Audio )?Video\]"#,
            #"\s*\(Official Audio\)"#,
            #"\s*\[Official Audio\]"#,
            #"\s*\(Audio\)"#,
            #"\s*\[Audio\]"#,
            #"\s*\(Lyric Video\)"#,
            #"\s*\[Lyric Video\]"#,
            #"\s*\(Lyrics\)"#,
            #"\s*\[Lyrics\]"#,
            #"\s*\(Visualizer\)"#,
            #"\s*\[Visualizer\]"#,
            #"\s*\(Video Oficial\)"#,
            #"\s*\[Video Oficial\]"#
        ]
        
        for pattern in removablePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
            }
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip redundant leading "Artist - " prefix when it matches the artist name
        let prefix = "\(artist) - "
        if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
            let dropCount = prefix.count
            if cleaned.count > dropCount {
                cleaned = String(cleaned.dropFirst(dropCount)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return cleaned.isEmpty ? title : cleaned
    }
}
