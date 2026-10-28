import SwiftUI

struct SearchView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    
    @State private var searchText: String = ""
    @State private var searchResults: [Song] = []
    @State private var suggestions: [String] = []
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
                
                if isLoading && searchResults.isEmpty && suggestions.isEmpty {
                    LoadingStateView(message: "Searching tracks...")
                } else if let error = errorMessage, searchResults.isEmpty {
                    ErrorStateView(message: error) {
                        Task { await performSearch(saveToHistory: true) }
                    }
                } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !searchResults.isEmpty {
                    if hasSearched && searchResults.isEmpty && suggestions.isEmpty && !isLoading {
                        EmptyStateView(
                            iconName: "magnifyingglass",
                            title: "No Results Found",
                            subtitle: "Check the spelling or try searching for another artist or song title."
                        )
                    } else {
                        List {
                            if !suggestions.isEmpty {
                                Section {
                                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                                        Button {
                                            searchText = suggestion
                                            Task { await performSearch(saveToHistory: true) }
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "magnifyingglass")
                                                    .foregroundColor(.secondary)
                                                    .font(.subheadline)
                                                Text(suggestion)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Spacer()
                                                Image(systemName: "arrow.up.left")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(minHeight: 38)
                                        }
                                    }
                                }
                            }
                            
                            if !searchResults.isEmpty {
                                Section("Songs (\(searchResults.count))") {
                                    ForEach(searchResults) { song in
                                        SongRowView(
                                            song: song,
                                            isCurrentSong: player.currentSong?.id == song.id,
                                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                                            onSelect: {
                                                let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !trimmed.isEmpty {
                                                    addToHistory(trimmed)
                                                }
                                                player.playSong(song, queue: searchResults)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollDismissesKeyboard(.immediately)
                    }
                } else {
                    // Default search landing with history
                    if !searchHistory.isEmpty {
                        List {
                            Section {
                                ForEach(searchHistory, id: \.self) { item in
                                    Button {
                                        searchText = item
                                        Task { await performSearch(saveToHistory: true) }
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
            .safeAreaInset(edge: .bottom) {
                if player.currentSong != nil {
                    Color.clear.frame(height: 68)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search tracks, artists, albums...")
            .onSubmit(of: .search) {
                Task { await performSearch(saveToHistory: true) }
            }
            .task(id: searchText) {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.isEmpty {
                    suggestions = []
                    searchResults = []
                    hasSearched = false
                    errorMessage = nil
                    isLoading = false
                    return
                }
                
                // Debounce 300ms for live search-as-you-type
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                
                async let fetchedSuggestions = MusicSearchService.shared.fetchSearchSuggestions(query: query)
                let liveSuggestions = await fetchedSuggestions
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.suggestions = liveSuggestions
                }
                
                await performSearch(saveToHistory: false)
            }
            .onAppear {
                loadHistory()
            }
        }
    }
    
    private func performSearch(saveToHistory: Bool) async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        if saveToHistory {
            await MainActor.run {
                addToHistory(query)
                suggestions = []
            }
        }
        
        await MainActor.run {
            if searchResults.isEmpty {
                isLoading = true
            }
            errorMessage = nil
            hasSearched = true
        }
        
        do {
            let results = try await MusicSearchService.shared.searchSongs(query: query)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.searchResults = results
                self.isLoading = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self.searchResults.isEmpty {
                    self.errorMessage = error.localizedDescription
                }
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
