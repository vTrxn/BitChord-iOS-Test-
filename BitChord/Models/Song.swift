import Foundation

struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let durationSeconds: Int
    let thumbnailURL: URL?
    var highResThumbnailURL: URL? {
        // Generates YouTube maxres / hqdefault fallback if standard URL is thumbnail
        if let original = thumbnailURL?.absoluteString, original.contains("youtube.com") || original.contains("ggpht.com") {
            return URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
        }
        return thumbnailURL
    }
    let albumName: String?
    var streamURL: URL?
    var isDownloaded: Bool = false
    var localFilePath: String?
    
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
