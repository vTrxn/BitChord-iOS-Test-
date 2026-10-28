import Foundation

/// Audio stream bitrate preference for remote playback and offline downloads.
enum StreamQuality: String, CaseIterable, Codable {
    case high = "High (160 kbps)"
    case medium = "Medium (128 kbps)"
    case dataSaver = "Data Saver (64 kbps)"
    
    /// Target bitrate in bits per second used to match adaptive stream formats.
    var targetBitrate: Int {
        switch self {
        case .high:
            return 160_000
        case .medium:
            return 128_000
        case .dataSaver:
            return 64_000
        }
    }
}
