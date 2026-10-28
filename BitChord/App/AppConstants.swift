import Foundation

/// Central configuration parameters for BitChord iOS.
/// Holds endpoints, instance defaults, and local persistence keys.
enum AppConstants {
    static let appName = "BitChord"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"
    
    /// Default HTTPS instances used for YouTube audio streams and search metadata.
    /// These nodes support the Invidious REST API format.
    static let defaultInstances: [String] = [
        "https://yt.chocolatemoo53.com",
        "https://invidious.nerdvpn.de",
        "https://inv.nadeko.net",
        "https://invidious.tiekoetter.com"
    ]
    
    /// Base URL for the LRCLIB open-source lyrics provider.
    static let lrclibBaseURL = "https://lrclib.net/api"
    
    /// Invidious directory endpoint for dynamically discovering operational nodes.
    static let instancesListURL = "https://api.invidious.io/instances.json?sort_by=health"
    
    /// Key definitions for UserDefaults and local disk cache namespaces.
    enum StorageKey {
        static let favorites = "bitchord_favorites_v1"
        static let playlists = "bitchord_playlists_v1"
        static let recentHistory = "bitchord_history_v1"
        static let selectedInstance = "bitchord_selected_instance"
        static let streamQuality = "bitchord_stream_quality"
        static let downloads = "bitchord_saved_downloads"
        static let searchHistory = "bitchord_search_history"
    }
}
