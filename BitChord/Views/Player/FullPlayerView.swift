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
            let isCompact = availableHeight < 700
            let artworkSize = max(150, min(availableWidth - 56, availableHeight * 0.38, 310))
            
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if let song = player.currentSong {
                    VStack(spacing: isCompact ? 12 : 18) {
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
                        
                        Spacer(minLength: 2)
                        
                        // Album Artwork
                        CachedAsyncImage(url: song.highResThumbnailURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.34)
                        } placeholder: {
                            ZStack {
                                Color(.secondarySystemBackground)
                                Image(systemName: "music.note")
                                    .font(.system(size: isCompact ? 40 : 56))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: artworkSize, height: artworkSize)
                        .clipped()
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
                        
                        Spacer(minLength: 2)
                        
                        // Title, Artist and Favorite
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title)
                                    .font((isCompact ? Font.headline : Font.title3).weight(.bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                
                                Text(song.artist)
                                    .font(isCompact ? .subheadline : .body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .layoutPriority(1)
                            
                            Spacer(minLength: 8)
                            
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
                        HStack(spacing: isCompact ? 18 : 26) {
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
                                        .frame(width: isCompact ? 56 : 64, height: isCompact ? 56 : 64)
                                    
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
                        
                        Spacer(minLength: 2)
                        
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
                    }
                    .padding(.vertical, 8)
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
