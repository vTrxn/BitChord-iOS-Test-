import SwiftUI

struct PlaylistDetailView: View {
    let title: String
    let subtitle: String?
    let songs: [Song]
    var onRemoveSong: ((String) -> Void)? = nil
    
    @ObservedObject private var player = AudioPlayerManager.shared
    
    var body: some View {
        List {
            if songs.isEmpty {
                EmptyStateView(
                    iconName: "music.note",
                    title: "No Songs in Playlist",
                    subtitle: "Add songs to this playlist from the search or discover tabs."
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    Button {
                        if let first = songs.first {
                            player.playSong(first, queue: songs)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play All")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(songs.count) tracks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(minHeight: 44)
                        .foregroundColor(.accentColor)
                    }
                }
                
                Section {
                    ForEach(songs) { song in
                        SongRowView(
                            song: song,
                            isCurrentSong: player.currentSong?.id == song.id,
                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                            onSelect: {
                                player.playSong(song, queue: songs)
                            }
                        )
                    }
                    .onDelete { indexSet in
                        if let remove = onRemoveSong {
                            for index in indexSet {
                                remove(songs[index].id)
                            }
                        }
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
