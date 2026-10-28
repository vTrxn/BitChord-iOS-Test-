import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    let onTap: () -> Void
    
    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 0) {
                // Top 2px progress line
                GeometryReader { geo in
                    let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 2)
                }
                .frame(height: 2)
                
                HStack(spacing: 12) {
                    // Thumbnail
                    CachedAsyncImage(url: song.thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color(.tertiarySystemFill)
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(6)
                    
                    // Song Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(song.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                    
                    Spacer(minLength: 8)
                    
                    // Play / Pause Button (44x44 tap target)
                    Button {
                        player.togglePlayPause()
                    } label: {
                        ZStack {
                            if player.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(width: 44, height: 44)
                    }
                    
                    // Next Button (44x44 tap target)
                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
            }
            .background(Color(.secondarySystemBackground))
            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: -2)
        }
    }
}
