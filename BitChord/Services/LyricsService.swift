import Foundation

final class LyricsService {
    static let shared = LyricsService()
    
    private init() {}
    
    func fetchLyrics(for song: Song) async -> ParsedLyrics {
        // Step 1: Try exact lookup with cleaned artist and track
        let cleanArtist = sanitize(song.artist)
        let cleanTrack = sanitize(song.title)
        
        if let exactLyrics = await tryExactLookup(artist: cleanArtist, track: cleanTrack, duration: song.durationSeconds) {
            return exactLyrics
        }
        
        // Step 2: Fall back to LRCLIB search endpoint
        return await trySearchLookup(query: "\(cleanArtist) \(cleanTrack)")
    }
    
    private func tryExactLookup(artist: String, track: String, duration: Int) async -> ParsedLyrics? {
        guard var components = URLComponents(string: "\(AppConstants.lrclibBaseURL)/get") else {
            return nil
        }
        
        var queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: track)
        ]
        if duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return parseLrcLibJSON(data)
        } catch {
            return nil
        }
    }
    
    private func trySearchLookup(query: String) async -> ParsedLyrics {
        guard var components = URLComponents(string: "\(AppConstants.lrclibBaseURL)/search") else {
            return .empty
        }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        
        guard let url = components.url else { return .empty }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .empty
            }
            
            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = array.first,
                  let firstData = try? JSONSerialization.data(withJSONObject: first) else {
                return .empty
            }
            
            return parseLrcLibJSON(firstData) ?? .empty
        } catch {
            return .empty
        }
    }
    
    private func parseLrcLibJSON(_ data: Data) -> ParsedLyrics? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let instrumental = (json["instrumental"] as? Bool) ?? false
        if instrumental {
            return ParsedLyrics(isSynced: false, lines: [], plainText: "Instrumental Track")
        }
        
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            let lines = ParsedLyrics.parseLRC(synced)
            let plain = (json["plainLyrics"] as? String) ?? ""
            return ParsedLyrics(isSynced: true, lines: lines, plainText: plain)
        }
        
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            return ParsedLyrics(isSynced: false, lines: [], plainText: plain)
        }
        
        return nil
    }
    
    private func sanitize(_ string: String) -> String {
        var result = string
        let regexes = [
            #" - Topic"#,
            #"VEVO"#,
            #"\s*\(feat\..*?\)"#,
            #"\s*\(ft\..*?\)"#,
            #"\s*\[feat\..*?\]"#,
            #"\s*\[ft\..*?\]"#
        ]
        
        for p in regexes {
            if let r = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = r.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
