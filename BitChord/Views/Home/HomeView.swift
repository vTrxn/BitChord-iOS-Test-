import SwiftUI

struct HomeView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var favorites = FavoritesManager.shared
    
    @State private var trendingSongs: [Song] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView(message: "Loading trending music...")
                } else if let error = errorMessage {
                    ErrorStateView(message: error) {
                        Task { await loadHomeContent() }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            // Recently Played
                            if !favorites.recentlyPlayed.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recently Played")
                                        .font(.title3.weight(.bold))
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(favorites.recentlyPlayed.prefix(10)) { song in
                                                RecentSongCard(song: song) {
                                                    player.playSong(song, queue: favorites.recentlyPlayed)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            // Trending Hits Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Trending Hits")
                                        .font(.title3.weight(.bold))
                                    Spacer()
                                    Button {
                                        if let first = trendingSongs.first {
                                            player.playSong(first, queue: trendingSongs)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                            Text("Play All")
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                                
                                LazyVStack(spacing: 0) {
                                    ForEach(trendingSongs) { song in
                                        SongRowView(
                                            song: song,
                                            isCurrentSong: player.currentSong?.id == song.id,
                                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                                            onSelect: {
                                                player.playSong(song, queue: trendingSongs)
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                        
                                        Divider()
                                            .padding(.leading, 78)
                                    }
                                }
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, player.currentSong != nil ? 64 : 16)
                    }
                    .refreshable {
                        await loadHomeContent()
                    }
                }
            }
            .navigationTitle("Discover")
            .task {
                if trendingSongs.isEmpty {
                    await loadHomeContent()
                }
            }
        }
    }
    
    private func loadHomeContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await MusicSearchService.shared.fetchTrending()
            await MainActor.run {
                self.trendingSongs = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct RecentSongCard: View {
    let song: Song
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                CachedAsyncImage(url: song.thumbnailURL) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                }
                .frame(width: 120, height: 120)
                .cornerRadius(8)
                
                Text(song.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
                
                Text(song.artist)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
