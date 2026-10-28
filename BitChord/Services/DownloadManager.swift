import Foundation

/// Coordinates downloading tracks to the app's sandboxed Documents directory for offline use.
/// Keeps track of active downloads and persists metadata of stored tracks.
@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    /// Array of fully downloaded songs present on local disk.
    @Published var downloadedSongs: [Song] = []
    
    /// Set of track identifiers currently being transferred over the network.
    @Published var downloadingSongIds: Set<String> = []
    
    private let fileManager = FileManager.default
    
    /// Dedicated subdirectory within Documents directory storing `.m4a` audio files.
    private var downloadFolderURL: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("BitChordDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {
        loadDownloads()
    }
    
    /// Returns true if a song is saved locally and its file exists on disk.
    func isDownloaded(songId: String) -> Bool {
        downloadedSongs.contains { $0.id == songId }
    }
    
    /// Returns true if a song is currently being fetched over the network.
    func isDownloading(songId: String) -> Bool {
        downloadingSongIds.contains(songId)
    }
    
    /// Resolves the stream URL and downloads the track file to local sandboxed storage.
    func downloadSong(_ song: Song) async {
        guard !isDownloaded(songId: song.id), !isDownloading(songId: song.id) else { return }
        
        self.downloadingSongIds.insert(song.id)
        
        do {
            let streamURL: URL
            if let existing = song.streamURL {
                streamURL = existing
            } else {
                streamURL = try await AudioStreamService.shared.resolveStreamURL(videoId: song.id)
            }
            
            let localURL = downloadFolderURL.appendingPathComponent("\(song.id).m4a")
            let (tempURL, _) = try await URLSession.shared.download(from: streamURL)
            
            if fileManager.fileExists(atPath: localURL.path) {
                try? fileManager.removeItem(at: localURL)
            }
            try fileManager.moveItem(at: tempURL, to: localURL)
            
            var savedSong = song
            savedSong.isDownloaded = true
            savedSong.localFilePath = localURL.path
            
            self.downloadedSongs.removeAll { $0.id == song.id }
            self.downloadedSongs.insert(savedSong, at: 0)
            self.downloadingSongIds.remove(song.id)
            self.persistDownloads()
        } catch {
            self.downloadingSongIds.remove(song.id)
        }
    }
    
    /// Removes audio file from disk and updates stored metadata.
    func removeDownload(songId: String) {
        let localURL = downloadFolderURL.appendingPathComponent("\(songId).m4a")
        try? fileManager.removeItem(at: localURL)
        
        downloadedSongs.removeAll { $0.id == songId }
        persistDownloads()
    }
    
    /// Encodes downloaded track list to UserDefaults.
    private func persistDownloads() {
        if let data = try? JSONEncoder().encode(downloadedSongs) {
            UserDefaults.standard.set(data, forKey: AppConstants.StorageKey.downloads)
        }
    }
    
    /// Loads stored downloads and prunes entries whose underlying file was removed.
    private func loadDownloads() {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.StorageKey.downloads),
              let decoded = try? JSONDecoder().decode([Song].self, from: data) else {
            return
        }
        self.downloadedSongs = decoded.filter { song in
            guard let path = song.localFilePath else { return false }
            return fileManager.fileExists(atPath: path)
        }
    }
}
