import SwiftUI

struct LyricsSheetView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if player.lyrics.isSynced && !player.lyrics.lines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(Array(player.lyrics.lines.enumerated()), id: \.element.id) { index, line in
                                    let isActive = index == player.activeLyricIndex
                                    
                                    Button {
                                        player.seek(to: line.timestamp)
                                    } label: {
                                        Text(line.text.isEmpty ? "•••" : line.text)
                                            .font(.system(size: isActive ? 24 : 18, weight: isActive ? .bold : .medium))
                                            .foregroundColor(isActive ? .accentColor : .secondary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 32)
                        }
                        .onChange(of: player.activeLyricIndex) { oldValue, newIndex in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                } else if !player.lyrics.plainText.isEmpty {
                    ScrollView {
                        Text(player.lyrics.plainText)
                            .font(.body)
                            .lineSpacing(8)
                            .foregroundColor(.primary)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    EmptyStateView(
                        iconName: "quote.bubble",
                        title: "No Lyrics Available",
                        subtitle: "We couldn't find synchronized lyrics for this song on LRCLIB."
                    )
                }
            }
            .navigationTitle(player.currentSong?.title ?? "Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
