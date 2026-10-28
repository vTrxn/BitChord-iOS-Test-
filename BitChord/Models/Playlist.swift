import Foundation

struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String?
    var songs: [Song]
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String, description: String? = nil, songs: [Song] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.songs = songs
        self.createdAt = createdAt
    }
    
    var totalDurationFormatted: String {
        let totalSeconds = songs.reduce(0) { $0 + $1.durationSeconds }
        let minutes = totalSeconds / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours) h \(remainingMinutes) min"
    }
}
