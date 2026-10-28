import Foundation

/// Resolves playable direct HTTP audio URLs for a given track identifier.
/// Extracts M4A/AAC streams compatible with iOS hardware decoders.
final class AudioStreamService {
    static let shared = AudioStreamService()
    
    private init() {}
    
    /// Resolves direct audio stream URL for a given video ID and target quality.
    /// Iterates through configured server instances until an operational stream is returned.
    /// Appends `local=true` to force node-side stream proxying, preventing Google IP 403 blocks.
    func resolveStreamURL(videoId: String, quality: StreamQuality = .high) async throws -> URL {
        let primaryInstance = await MainActor.run { InstanceManager.shared.activeInstance }
        let instances = [primaryInstance] + AppConstants.defaultInstances.filter { $0 != primaryInstance }
        
        for instance in instances {
            guard let url = URL(string: "\(instance)/api/v1/videos/\(videoId)?local=true") else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 7
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    continue
                }
                
                if let streamURL = extractAudioURL(from: data, targetBitrate: quality.targetBitrate, instance: instance) {
                    return streamURL
                }
            } catch {
                continue
            }
        }
        
        throw NetworkError.noAvailableInstance
    }
    
    /// Parses adaptive formats and picks the closest M4A stream matching target bitrate.
    /// If an instance emits a direct googlevideo URL, reroutes through the instance proxy to prevent client 403s.
    private func extractAudioURL(from data: Data, targetBitrate: Int, instance: String) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
            var audioStreams: [(url: URL, bitrate: Int, isM4A: Bool)] = []
            
            for format in adaptiveFormats {
                guard let type = format["type"] as? String,
                      type.contains("audio/"),
                      let urlStr = format["url"] as? String,
                      let url = URL(string: urlStr) else {
                    continue
                }
                
                let bitrate = (format["bitrate"] as? Int) ?? 0
                let isM4A = type.contains("audio/mp4")
                
                // If stream is googlevideo, proxy through the Invidious instance host
                if urlStr.contains("googlevideo.com"),
                   let instURL = URL(string: instance),
                   var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    components.scheme = instURL.scheme
                    components.host = instURL.host
                    components.port = instURL.port
                    if let proxiedURL = components.url {
                        audioStreams.append((url: proxiedURL, bitrate: bitrate, isM4A: isM4A))
                        continue
                    }
                }
                
                audioStreams.append((url: url, bitrate: bitrate, isM4A: isM4A))
            }
            
            let m4aStreams = audioStreams.filter { $0.isM4A }
            let pool = !m4aStreams.isEmpty ? m4aStreams : audioStreams
            
            if !pool.isEmpty {
                let sorted = pool.sorted { abs($0.bitrate - targetBitrate) < abs($1.bitrate - targetBitrate) }
                return sorted.first?.url
            }
        }
        
        if let formatStreams = json["formatStreams"] as? [[String: Any]] {
            for format in formatStreams {
                if let urlStr = format["url"] as? String, let url = URL(string: urlStr) {
                    return url
                }
            }
        }
        
        return nil
    }
}
