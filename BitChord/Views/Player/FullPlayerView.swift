import SwiftUI

struct FullPlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var favorites = FavoritesManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLyrics: Bool = false
    @State private var showingQueue: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let isCompact = availableHeight < 720
            let artworkSize = max(160, min(availableWidth - 72, availableHeight * 0.35, 280))
            
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if let song = player.currentSong {
                    VStack(spacing: isCompact ? 14 : 20) {
                        // Top Bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                            }
                            
                            Spacer()
                            
                            Text("Playing from Queue")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Spacer()
                            
                            Button {
                                showingQueue.toggle()
                            } label: {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 4)
                        
                        // Album Artwork
                        CachedAsyncImage(url: song.highResThumbnailURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ZStack {
                                Color(.secondarySystemBackground)
                                Image(systemName: "music.note")
                                    .font(.system(size: isCompact ? 40 : 56))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: artworkSize, height: artworkSize)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        
                        Spacer(minLength: 4)
                        
                        // Title, Artist and Favorite
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title)
                                    .font((isCompact ? Font.headline : Font.title3).weight(.bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(song.artist)
                                    .font(isCompact ? .subheadline : .body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button {
                                favorites.toggleLike(song: song)
                            } label: {
                                Image(systemName: favorites.isLiked(songId: song.id) ? "heart.fill" : "heart")
                                    .font(.system(size: 24))
                                    .foregroundColor(favorites.isLiked(songId: song.id) ? .red : .primary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Progress Scrubber Bar
                        ProgressBarView(
                            currentTime: $player.currentTime,
                            duration: player.duration,
                            onSeek: { target in
                                player.seek(to: target)
                            }
                        )
                        .padding(.horizontal, 24)
                        
                        // Playback Controls
                        HStack(spacing: isCompact ? 20 : 28) {
                            // Shuffle
                            Button {
                                player.toggleShuffle()
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 20))
                                    .foregroundColor(player.isShuffleEnabled ? .accentColor : .secondary)
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Previous
                            Button {
                                player.previous()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: isCompact ? 24 : 28))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Play/Pause
                            Button {
                                player.togglePlayPause()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: isCompact ? 54 : 64, height: isCompact ? 54 : 64)
                                    
                                    if player.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: isCompact ? 22 : 26))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 64, height: 64)
                            }
                            
                            // Next
                            Button {
                                player.next()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: isCompact ? 24 : 28))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Repeat
                            Button {
                                player.toggleRepeat()
                            } label: {
                                Image(systemName: player.repeatMode.iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(player.repeatMode != .off ? .accentColor : .secondary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        Spacer(minLength: 4)
                        
                        // Bottom lyrics button
                        Button {
                            showingLyrics = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "quote.bubble.fill")
                                Text("Lyrics")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(20)
                            .frame(minHeight: 44)
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.top, max(geo.safeAreaInsets.top, 8))
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 8))
                } else {
                    EmptyStateView(
                        iconName: "music.note",
                        title: "Nothing Playing",
                        subtitle: "Choose a track from Search or Library to start playing."
                    )
                }
            }
        }
        .sheet(isPresented: $showingLyrics) {
            LyricsSheetView()
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheetView()
        }
    }
}

struct QueueSheetView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Up Next (\(player.queue.count) tracks)") {
                    ForEach(Array(player.queue.indices), id: \.self) { index in
                        let song = player.queue[index]
                        SongRowView(
                            song: song,
                            isCurrentSong: index == player.currentIndex,
                            isPlaying: index == player.currentIndex && player.isPlaying,
                            onSelect: {
                                player.playSong(song, queue: player.queue)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
