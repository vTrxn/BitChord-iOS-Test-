import SwiftUI

@main
struct BitChordApp: App {
    // Eagerly initialize audio player and remote control handling
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @StateObject private var favorites = FavoritesManager.shared
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var instanceManager = InstanceManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(audioPlayer)
                .environmentObject(favorites)
                .environmentObject(downloads)
                .environmentObject(instanceManager)
        }
    }
}
