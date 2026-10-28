import Foundation

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

final class MusicSearchService {
    static let shared = MusicSearchService()
    
    private init() {}
    
    func searchSongs(query: String) async throws -> [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let instances = [InstanceManager.shared.activeInstance] + AppConstants.defaultInstances.filter { $0 != InstanceManager.shared.activeInstance }
        
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
    
    func fetchTrending() async throws -> [Song] {
        let instances = [InstanceManager.shared.activeInstance] + AppConstants.defaultInstances.filter { $0 != InstanceManager.shared.activeInstance }
        
        for instance in instances {
            guard let url = URL(string: "\(instance)/api/v1/popular") else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            
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
        
        // Fallback: search for top global hits if popular endpoint is disabled on the instance
        return try await searchSongs(query: "Top Global Hits 2024")
    }
    
    private func parseSearchItems(from data: Data) -> [Song] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var results: [Song] = []
        for item in jsonArray {
            guard let videoId = item["videoId"] as? String,
                  let title = item["title"] as? String else {
                continue
            }
            
            let author = (item["author"] as? String) ?? "Unknown Artist"
            let lengthSeconds = (item["lengthSeconds"] as? Int) ?? 0
            
            var thumbURL: URL? = nil
            if let thumbnails = item["videoThumbnails"] as? [[String: Any]] {
                // Find highest resolution available
                if let last = thumbnails.last, let urlStr = last["url"] as? String {
                    thumbURL = URL(string: urlStr)
                }
            }
            if thumbURL == nil {
                thumbURL = URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
            }
            
            let song = Song(
                id: videoId,
                title: cleanTitle(title),
                artist: author,
                durationSeconds: lengthSeconds,
                thumbnailURL: thumbURL,
                albumName: nil
            )
            results.append(song)
        }
        
        return results
    }
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let removablePatterns = [
            #"\s*\(Official (Music )?Video\)"#,
            #"\s*\[Official (Music )?Video\]"#,
            #"\s*\(Official Audio\)"#,
            #"\s*\[Official Audio\]"#,
            #"\s*\(Audio\)"#,
            #"\s*\(Lyric Video\)"#,
            #"\s*\[Lyric Video\]"#
        ]
        
        for pattern in removablePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
