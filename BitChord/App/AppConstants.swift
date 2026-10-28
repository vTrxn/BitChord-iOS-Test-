import Foundation

enum AppConstants {
    static let appName = "BitChord"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"
    
    // Default reliable Invidious / audio instances for stream resolution
    static let defaultInstances: [String] = [
        "https://yt.chocolatemoo53.com",
        "https://invidious.nerdvpn.de",
        "https://inv.nadeko.net",
        "https://invidious.tiekoetter.com"
    ]
    
    // LRCLIB public API for synchronized and plain lyrics
    static let lrclibBaseURL = "https://lrclib.net/api"
    
    // Instances health checker
    static let instancesListURL = "https://api.invidious.io/instances.json?sort_by=health"
    
    // Storage keys
    enum StorageKey {
        static let favorites = "bitchord_favorites_v1"
        static let playlists = "bitchord_playlists_v1"
        static let recentHistory = "bitchord_history_v1"
        static let selectedInstance = "bitchord_selected_instance"
        static let streamQuality = "bitchord_stream_quality"
    }
}
