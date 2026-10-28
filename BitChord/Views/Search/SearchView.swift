import SwiftUI

struct SearchView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    
    @State private var searchText: String = ""
    @State private var searchResults: [Song] = []
    @State private var searchHistory: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var hasSearched: Bool = false
    
    private let historyStorageKey = "bitchord_search_history"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        LoadingStateView(message: "Searching tracks...")
                    } else if let error = errorMessage {
                        ErrorStateView(message: error) {
                            Task { await performSearch() }
                        }
                    } else if hasSearched && searchResults.isEmpty {
                        EmptyStateView(
                            iconName: "magnifyingglass",
                            title: "No Results Found",
                            subtitle: "Check the spelling or try searching for another artist or song title."
                        )
                    } else if !searchResults.isEmpty {
                        List {
                            Section("Search Results (\(searchResults.count))") {
                                ForEach(searchResults) { song in
                                    SongRowView(
                                        song: song,
                                        isCurrentSong: player.currentSong?.id == song.id,
                                        isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                                        onSelect: {
                                            player.playSong(song, queue: searchResults)
                                        }
                                    )
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    } else {
                        // Default search landing with history
                        if !searchHistory.isEmpty {
                            List {
                                Section {
                                    ForEach(searchHistory, id: \.self) { item in
                                        Button {
                                            searchText = item
                                            Task { await performSearch() }
                                        } label: {
                                            HStack {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .foregroundColor(.secondary)
                                                Text(item)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Image(systemName: "arrow.up.left")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(minHeight: 44)
                                        }
                                    }
                                    .onDelete(perform: deleteHistoryItem)
                                } header: {
                                    HStack {
                                        Text("Recent Searches")
                                        Spacer()
                                        Button("Clear") {
                                            searchHistory.removeAll()
                                            saveHistory()
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        } else {
                            EmptyStateView(
                                iconName: "music.note.list",
                                title: "Find Any Song",
                                subtitle: "Search for songs, artists, and albums from the entire YouTube Music catalog."
                            )
                        }
                    }
                }
                .padding(.bottom, player.currentSong != nil ? 64 : 0)
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search tracks, artists, albums...")
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .onAppear {
                loadHistory()
            }
        }
    }
    
    private func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        addToHistory(query)
        isLoading = true
        errorMessage = nil
        hasSearched = true
        
        do {
            let results = try await MusicSearchService.shared.searchSongs(query: query)
            await MainActor.run {
                self.searchResults = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func addToHistory(_ query: String) {
        searchHistory.removeAll { $0.lowercased() == query.lowercased() }
        searchHistory.insert(query, at: 0)
        if searchHistory.count > 15 {
            searchHistory = Array(searchHistory.prefix(15))
        }
        saveHistory()
    }
    
    private func deleteHistoryItem(at offsets: IndexSet) {
        searchHistory.remove(atOffsets: offsets)
        saveHistory()
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(searchHistory, forKey: historyStorageKey)
    }
    
    private func loadHistory() {
        if let saved = UserDefaults.standard.stringArray(forKey: historyStorageKey) {
            self.searchHistory = saved
        }
    }
}
