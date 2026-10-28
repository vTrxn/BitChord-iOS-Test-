import SwiftUI

/// Standard track list item with thumbnail art, metadata, context menu, and active playback indicator.
struct SongRowView: View {
    let song: Song
    let isCurrentSong: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    
    @ObservedObject private var favorites = FavoritesManager.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var showingPlaylistSheet: Bool = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color(.tertiarySystemFill)
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .clipped()
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isCurrentSong ? .accentColor : .primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 5) {
                        if downloads.isDownloaded(songId: song.id) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        Text(song.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
                
                Spacer(minLength: 6)
                
                if song.durationSeconds > 0 {
                    Text(song.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                Menu {
                    Button {
                        favorites.toggleLike(song: song)
                    } label: {
                        Label(
                            favorites.isLiked(songId: song.id) ? "Remove from Favorites" : "Favorite",
                            systemImage: favorites.isLiked(songId: song.id) ? "heart.slash" : "heart"
                        )
                    }
                    
                    Button {
                        showingPlaylistSheet = true
                    } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    
                    if downloads.isDownloaded(songId: song.id) {
                        Button(role: .destructive) {
                            downloads.removeDownload(songId: song.id)
                        } label: {
                            Label("Remove Download", systemImage: "trash")
                        }
                    } else if downloads.isDownloading(songId: song.id) {
                        Text("Downloading...")
                    } else {
                        Button {
                            Task {
                                await downloads.downloadSong(song)
                            }
                        } label: {
                            Label("Download Offline", systemImage: "arrow.down.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPlaylistSheet) {
            AddToPlaylistSheet(song: song)
        }
    }
}

/// Modal selector sheet allowing the user to add the selected song to an existing or new playlist.
struct AddToPlaylistSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var favorites = FavoritesManager.shared
    @State private var newPlaylistTitle = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            List {
                if favorites.customPlaylists.isEmpty && !isCreating {
                    Section {
                        Text("No playlists yet. Create one below.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Your Playlists") {
                    ForEach(favorites.customPlaylists) { playlist in
                        Button {
                            favorites.addSong(song, toPlaylistId: playlist.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(playlist.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(playlist.songs.count) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                
                Section("New Playlist") {
                    HStack {
                        TextField("Playlist Name", text: $newPlaylistTitle)
                        if !newPlaylistTitle.isEmpty {
                            Button("Create") {
                                favorites.createPlaylist(title: newPlaylistTitle)
                                if let created = favorites.customPlaylists.first {
                                    favorites.addSong(song, toPlaylistId: created.id)
                                }
                                dismiss()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
