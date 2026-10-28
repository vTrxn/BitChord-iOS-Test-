import Foundation

final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloadedSongs: [Song] = []
    @Published var downloadingSongIds: Set<String> = []
    
    private let fileManager = FileManager.default
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
    
    func isDownloaded(songId: String) -> Bool {
        downloadedSongs.contains { $0.id == songId }
    }
    
    func isDownloading(songId: String) -> Bool {
        downloadingSongIds.contains(songId)
    }
    
    func downloadSong(_ song: Song) async {
        guard !isDownloaded(songId: song.id), !isDownloading(songId: song.id) else { return }
        
        await MainActor.run {
            self.downloadingSongIds.insert(song.id)
        }
        
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
            
            await MainActor.run {
                self.downloadedSongs.removeAll { $0.id == song.id }
                self.downloadedSongs.insert(savedSong, at: 0)
                self.downloadingSongIds.remove(song.id)
                self.persistDownloads()
            }
        } catch {
            await MainActor.run {
                self.downloadingSongIds.remove(song.id)
            }
        }
    }
    
    func removeDownload(songId: String) {
        let localURL = downloadFolderURL.appendingPathComponent("\(songId).m4a")
        try? fileManager.removeItem(at: localURL)
        
        downloadedSongs.removeAll { $0.id == songId }
        persistDownloads()
    }
    
    private func persistDownloads() {
        if let data = try? JSONEncoder().encode(downloadedSongs) {
            UserDefaults.standard.set(data, forKey: "bitchord_saved_downloads")
        }
    }
    
    private func loadDownloads() {
        guard let data = UserDefaults.standard.data(forKey: "bitchord_saved_downloads"),
              let decoded = try? JSONDecoder().decode([Song].self, from: data) else {
            return
        }
        // Verify files actually exist on disk
        self.downloadedSongs = decoded.filter { song in
            guard let path = song.localFilePath else { return false }
            return fileManager.fileExists(atPath: path)
        }
    }
}
