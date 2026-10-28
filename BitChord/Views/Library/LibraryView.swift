import SwiftUI

struct LibraryView: View {
    @ObservedObject private var favorites = FavoritesManager.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var player = AudioPlayerManager.shared
    
    @State private var showingCreatePlaylist: Bool = false
    @State private var newPlaylistName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Collections
                Section {
                    NavigationLink {
                        PlaylistDetailView(
                            title: "Favorites",
                            subtitle: "\(favorites.likedSongs.count) songs",
                            songs: favorites.likedSongs,
                            onRemoveSong: { songId in
                                if let song = favorites.likedSongs.first(where: { $0.id == songId }) {
                                    favorites.toggleLike(song: song)
                                }
                            }
                        )
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.15))
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                            .frame(width: 44, height: 44)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Liked Songs")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("\(favorites.likedSongs.count) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink {
                        PlaylistDetailView(
                            title: "Downloaded",
                            subtitle: "\(downloads.downloadedSongs.count) offline songs",
                            songs: downloads.downloadedSongs,
                            onRemoveSong: { songId in
                                downloads.removeDownload(songId: songId)
                            }
                        )
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.15))
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .frame(width: 44, height: 44)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Offline Downloads")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("\(downloads.downloadedSongs.count) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Collections")
                }
                
                // Custom Playlists Section
                Section {
                    if favorites.customPlaylists.isEmpty {
                        Text("No custom playlists yet. Tap 'New Playlist' to create one.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(favorites.customPlaylists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(
                                    title: playlist.title,
                                    subtitle: playlist.totalDurationFormatted,
                                    songs: playlist.songs,
                                    onRemoveSong: { songId in
                                        favorites.removeSong(songId: songId, fromPlaylistId: playlist.id)
                                    }
                                )
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.accentColor.opacity(0.15))
                                        Image(systemName: "music.note.list")
                                            .foregroundColor(.accentColor)
                                    }
                                    .frame(width: 44, height: 44)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.title)
                                            .font(.body.weight(.medium))
                                            .foregroundColor(.primary)
                                        Text("\(playlist.songs.count) songs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                favorites.deletePlaylist(id: favorites.customPlaylists[index].id)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Playlists")
                        Spacer()
                        Button {
                            newPlaylistName = ""
                            showingCreatePlaylist = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("New Playlist")
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if player.currentSong != nil {
                    Color.clear.frame(height: 68)
                }
            }
            .navigationTitle("Library")
            .alert("Create Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    favorites.createPlaylist(title: newPlaylistName)
                }
            }
        }
    }
}
