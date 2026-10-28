import Foundation

enum StreamQuality: String, CaseIterable, Codable {
    case high = "High (160 kbps)"
    case medium = "Medium (128 kbps)"
    case dataSaver = "Data Saver (64 kbps)"
    
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
