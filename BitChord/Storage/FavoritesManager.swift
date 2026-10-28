import Foundation

/// Manages local user data: Liked Songs, custom playlists, and recently played history.
/// Saves serialized JSON data directly to UserDefaults.
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    /// User's favorite tracks.
    @Published var likedSongs: [Song] = []
    
    /// Chronological list of recently played tracks (capped at 50).
    @Published var recentlyPlayed: [Song] = []
    
    /// Custom playlists created by the user.
    @Published var customPlaylists: [Playlist] = []
    
    private init() {
        loadData()
    }
    
    func isLiked(songId: String) -> Bool {
        likedSongs.contains { $0.id == songId }
    }
    
    /// Adds or removes track from Liked Songs collection.
    func toggleLike(song: Song) {
        if isLiked(songId: song.id) {
            likedSongs.removeAll { $0.id == song.id }
        } else {
            likedSongs.insert(song, at: 0)
        }
        persistLiked()
    }
    
    /// Appends track to recently played history, maintaining a maximum size of 50.
    func recordRecent(song: Song) {
        recentlyPlayed.removeAll { $0.id == song.id }
        recentlyPlayed.insert(song, at: 0)
        if recentlyPlayed.count > 50 {
            recentlyPlayed = Array(recentlyPlayed.prefix(50))
        }
        persistRecents()
    }
    
    func createPlaylist(title: String, description: String? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(title: trimmed, description: description)
        customPlaylists.insert(playlist, at: 0)
        persistPlaylists()
    }
    
    func deletePlaylist(id: UUID) {
        customPlaylists.removeAll { $0.id == id }
        persistPlaylists()
    }
    
    func addSong(_ song: Song, toPlaylistId id: UUID) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == id }) else { return }
        if !customPlaylists[index].songs.contains(where: { $0.id == song.id }) {
            customPlaylists[index].songs.append(song)
            persistPlaylists()
        }
    }
    
    func removeSong(songId: String, fromPlaylistId id: UUID) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == id }) else { return }
        customPlaylists[index].songs.removeAll { $0.id == songId }
        persistPlaylists()
    }
    
    private func persistLiked() {
        if let data = try? JSONEncoder().encode(likedSongs) {
            UserDefaults.standard.set(data, forKey: AppConstants.StorageKey.favorites)
        }
    }
    
    private func persistRecents() {
        if let data = try? JSONEncoder().encode(recentlyPlayed) {
            UserDefaults.standard.set(data, forKey: AppConstants.StorageKey.recentHistory)
        }
    }
    
    private func persistPlaylists() {
        if let data = try? JSONEncoder().encode(customPlaylists) {
            UserDefaults.standard.set(data, forKey: AppConstants.StorageKey.playlists)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: AppConstants.StorageKey.favorites),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            self.likedSongs = songs
        }
        if let data = UserDefaults.standard.data(forKey: AppConstants.StorageKey.recentHistory),
           let recents = try? JSONDecoder().decode([Song].self, from: data) {
            self.recentlyPlayed = recents
        }
        if let data = UserDefaults.standard.data(forKey: AppConstants.StorageKey.playlists),
           let playlists = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.customPlaylists = playlists
        }
    }
}
