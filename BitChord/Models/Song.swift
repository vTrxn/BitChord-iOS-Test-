import Foundation

/// Represents an audio track in the library, search results, or playback queue.
/// Conforms to Codable for persistent disk caching and Equatable/Hashable for SwiftUI list diffing.
struct Song: Identifiable, Codable, Equatable, Hashable {
    /// Unique track identifier (typically the YouTube 11-character video ID).
    let id: String
    
    /// Display title of the track, cleaned of common video tags.
    let title: String
    
    /// Primary performing artist or channel name.
    let artist: String
    
    /// Total duration in seconds.
    let durationSeconds: Int
    
    /// Remote URL pointing to album or video thumbnail art.
    let thumbnailURL: URL?
    
    /// Returns a higher resolution thumbnail from YouTube's global image CDN.
    var highResThumbnailURL: URL? {
        if !id.isEmpty, let hq = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg") {
            return hq
        }
        return thumbnailURL
    }
    
    /// Album or EP name if provided by the metadata provider.
    let albumName: String?
    
    /// Direct remote HTTP audio stream URL (resolved dynamically at playback time).
    var streamURL: URL?
    
    /// Flag indicating whether the track audio file exists in the device local sandbox.
    var isDownloaded: Bool = false
    
    /// Local file path on device storage if downloaded.
    var localFilePath: String?
    
    /// Formatted duration string in `m:ss` representation.
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, artist, durationSeconds, thumbnailURL, albumName, streamURL, isDownloaded, localFilePath
    }
    
    init(
        id: String,
        title: String,
        artist: String,
        durationSeconds: Int = 0,
        thumbnailURL: URL? = nil,
        albumName: String? = nil,
        streamURL: URL? = nil,
        isDownloaded: Bool = false,
        localFilePath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.durationSeconds = durationSeconds
        self.thumbnailURL = Self.resolveThumbnail(url: thumbnailURL, videoId: id)
        self.albumName = albumName
        self.streamURL = streamURL
        self.isDownloaded = isDownloaded
        self.localFilePath = localFilePath
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decode(String.self, forKey: .id)
        self.id = decodedId
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.durationSeconds = (try? container.decode(Int.self, forKey: .durationSeconds)) ?? 0
        let rawThumb = try? container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        self.thumbnailURL = Self.resolveThumbnail(url: rawThumb, videoId: decodedId)
        self.albumName = try? container.decodeIfPresent(String.self, forKey: .albumName)
        self.streamURL = try? container.decodeIfPresent(URL.self, forKey: .streamURL)
        self.isDownloaded = (try? container.decode(Bool.self, forKey: .isDownloaded)) ?? false
        self.localFilePath = try? container.decodeIfPresent(String.self, forKey: .localFilePath)
    }
    
    /// Guarantees a valid HTTPS thumbnail URL even if the API or cached storage provided a relative path.
    private static func resolveThumbnail(url: URL?, videoId: String) -> URL? {
        if let valid = url, let scheme = valid.scheme, scheme.hasPrefix("http"), valid.host != nil {
            return valid
        }
        guard !videoId.isEmpty else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg")
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
