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
    
    /// Returns a higher resolution thumbnail if the original is hosted on Google or YouTube servers.
    var highResThumbnailURL: URL? {
        if let original = thumbnailURL?.absoluteString, original.contains("youtube.com") || original.contains("ggpht.com") {
            return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
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
        self.thumbnailURL = thumbnailURL
        self.albumName = albumName
        self.streamURL = streamURL
        self.isDownloaded = isDownloaded
        self.localFilePath = localFilePath
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
