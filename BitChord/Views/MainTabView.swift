import SwiftUI

struct MainTabView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var showingFullPlayer: Bool = false
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Discover", systemImage: "sparkles")
                    }
                    .tag(0)
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)
                
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.note.house.fill")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            
            // Persistent Mini-Player docked right above the TabBar
            if player.currentSong != nil {
                MiniPlayerView {
                    showingFullPlayer = true
                }
                .padding(.bottom, 49) // Height of standard iOS tab bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            FullPlayerView()
        }
    }
}
