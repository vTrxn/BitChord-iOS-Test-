import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// Playback repetition mode.
enum RepeatMode: String, CaseIterable {
    case off = "Off"
    case all = "All"
    case one = "One"
    
    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat.1"
        case .one: return "repeat.1.circle.fill"
        }
    }
}

/// Core audio engine managing playback, background audio session, queue state, and system events.
/// ObservableObject publishing player updates directly to SwiftUI views on the main thread.
@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    /// Track currently playing or loaded in the player.
    @Published var currentSong: Song?
    
    /// Playback state.
    @Published var isPlaying: Bool = false
    
    /// True while network stream resolution or audio buffering is in progress.
    @Published var isLoading: Bool = false
    
    /// Current playback progress in seconds.
    @Published var currentTime: TimeInterval = 0
    
    /// Total duration of the active audio item in seconds.
    @Published var duration: TimeInterval = 1
    
    /// Ordered list of upcoming tracks.
    @Published var queue: [Song] = []
    
    /// Index of the currently active track within `queue`.
    @Published var currentIndex: Int = 0
    
    /// Shuffle mode state.
    @Published var isShuffleEnabled: Bool = false
    
    /// Repeat behavior when a track finishes playing.
    @Published var repeatMode: RepeatMode = .off
    
    /// Lyrics model loaded for `currentSong`.
    @Published var lyrics: ParsedLyrics = .empty
    
    /// Index of the current active line in `lyrics.lines` matching `currentTime`.
    @Published var activeLyricIndex: Int = 0
    
    /// User-facing error message if stream loading fails.
    @Published var errorMessage: String?
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var artworkCache: [String: UIImage] = [:]
    private var originalQueue: [Song] = []
    private var lastSyncedSecond: Int = -1
    private var isAdvancingTrack: Bool = false
    
    private init() {
        configureAudioSession()
        setupNotifications()
        setupRemoteCommands()
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    /// Activates the AVAudioSession with `.playback` category for continuous background and lockscreen audio.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }
    
    /// Registers observers for track completion, background state transitions, audio interruptions, and route changes.
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackEnded),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    /// Binds lockscreen and Control Center media keys to playback controls.
    private func setupRemoteCommands() {
        NowPlayingManager.shared.setupRemoteCommands(
            onPlay: { [weak self] in
                Task { @MainActor in self?.resume() }
            },
            onPause: { [weak self] in
                Task { @MainActor in self?.pause() }
            },
            onTogglePlayPause: { [weak self] in
                Task { @MainActor in self?.togglePlayPause() }
            },
            onNext: { [weak self] in
                Task { @MainActor in self?.next() }
            },
            onPrevious: { [weak self] in
                Task { @MainActor in self?.previous() }
            },
            onSeek: { [weak self] time in
                Task { @MainActor in self?.seek(to: time) }
            }
        )
    }
    
    /// Initiates playback for a track and configures the active queue.
    func playSong(_ song: Song, queue: [Song] = []) {
        self.currentSong = song
        self.errorMessage = nil
        self.isLoading = true
        self.currentTime = 0
        self.lastSyncedSecond = -1
        self.isAdvancingTrack = false
        self.duration = song.durationSeconds > 0 ? Double(song.durationSeconds) : 1
        self.lyrics = .empty
        self.activeLyricIndex = 0
        
        FavoritesManager.shared.recordRecent(song: song)
        
        if !queue.isEmpty {
            self.originalQueue = queue
            self.queue = isShuffleEnabled ? queue.shuffled() : queue
            if let idx = self.queue.firstIndex(where: { $0.id == song.id }) {
                self.currentIndex = idx
            }
        } else if self.queue.isEmpty {
            self.queue = [song]
            self.originalQueue = [song]
            self.currentIndex = 0
        }
        
        Task {
            await startPlayback(for: song)
            await fetchLyrics(for: song)
        }
    }
    
    /// Resolves local or remote audio stream and starts player item playback.
    private func startPlayback(for song: Song) async {
        do {
            let playbackURL: URL
            
            if let localPath = song.localFilePath, FileManager.default.fileExists(atPath: localPath) {
                playbackURL = URL(fileURLWithPath: localPath)
            } else if let streamURL = song.streamURL {
                playbackURL = streamURL
            } else {
                playbackURL = try await AudioStreamService.shared.resolveStreamURL(videoId: song.id)
            }
            
            self.setupPlayer(with: playbackURL, song: song)
            self.isLoading = false
            self.isPlaying = true
            self.updateNowPlayingInfo()
            
            if let thumbURL = song.highResThumbnailURL ?? song.thumbnailURL {
                loadArtwork(from: thumbURL, for: song.id)
            }
        } catch {
            self.isLoading = false
            self.isPlaying = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    /// Replaces player item and registers periodic time observer updating 4 times per second.
    private func setupPlayer(with url: URL, song: Song) {
        removeTimeObserver()
        configureAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        if player == nil {
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            newPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
            newPlayer.preventsDisplaySleepDuringVideoPlayback = false
            player = newPlayer
        } else {
            player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
            player?.preventsDisplaySleepDuringVideoPlayback = false
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            Task { @MainActor in
                guard !seconds.isNaN, seconds >= 0 else { return }
                self.currentTime = seconds
                self.updateActiveLyricIndex(at: seconds)
                
                if let currentItem = self.player?.currentItem {
                    let itemDuration = CMTimeGetSeconds(currentItem.duration)
                    if !itemDuration.isNaN, itemDuration > 0 {
                        let knownSeconds = Double(self.currentSong?.durationSeconds ?? 0)
                        if knownSeconds <= 0 {
                            self.duration = itemDuration
                        } else if abs(itemDuration - knownSeconds) <= 15 {
                            self.duration = itemDuration
                        } else {
                            // Keep accurate API metadata duration when DASH mvhd header reports 2x container length
                            self.duration = knownSeconds
                        }
                    }
                }
                
                // Periodically keep Lock Screen elapsed time synced
                let wholeSec = Int(seconds)
                if wholeSec != self.lastSyncedSecond && wholeSec % 2 == 0 {
                    self.lastSyncedSecond = wholeSec
                    self.updateNowPlayingInfo()
                }
                
                // Advance automatically when reaching known song duration even if DASH container has trailing silence
                if !self.isAdvancingTrack, self.duration > 10, seconds >= self.duration - 0.25 {
                    self.isAdvancingTrack = true
                    self.next()
                }
            }
        }
    }
    
    /// Queries LRCLIB for track lyrics.
    private func fetchLyrics(for song: Song) async {
        let fetched = await LyricsService.shared.fetchLyrics(for: song)
        self.lyrics = fetched
    }
    
    /// Computes the index of the line active at the specified playback second.
    private func updateActiveLyricIndex(at currentTime: TimeInterval) {
        guard lyrics.isSynced, !lyrics.lines.isEmpty else { return }
        if let idx = lyrics.lines.lastIndex(where: { $0.timestamp <= currentTime }) {
            if activeLyricIndex != idx {
                activeLyricIndex = idx
            }
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func resume() {
        configureAudioSession()
        player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    /// Seeks playback position to the given target time in seconds.
    func seek(to seconds: TimeInterval) {
        let target = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        updateNowPlayingInfo()
    }
    
    /// Advances to the next track in queue or loops based on repeatMode.
    func next() {
        guard !queue.isEmpty else { return }
        if repeatMode == .one, currentSong != nil {
            isAdvancingTrack = false
            seek(to: 0)
            resume()
            return
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex < queue.count {
            currentIndex = nextIndex
            playSong(queue[nextIndex], queue: queue)
        } else if repeatMode == .all {
            currentIndex = 0
            playSong(queue[0], queue: queue)
        } else {
            pause()
        }
    }
    
    /// Restarts current track if playback elapsed is > 3 seconds, or moves to previous track.
    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            currentIndex = prevIndex
            playSong(queue[prevIndex], queue: queue)
        } else if let _ = currentSong {
            seek(to: 0)
        }
    }
    
    /// Toggles shuffle mode, reordering the upcoming queue while preserving current track.
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        guard let current = currentSong else { return }
        
        if isShuffleEnabled {
            var shuffled = originalQueue.filter { $0.id != current.id }.shuffled()
            shuffled.insert(current, at: 0)
            queue = shuffled
            currentIndex = 0
        } else {
            queue = originalQueue
            if let idx = queue.firstIndex(where: { $0.id == current.id }) {
                currentIndex = idx
            }
        }
    }
    
    /// Cycles through repeat modes: off -> all -> one -> off.
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    /// Sends current track details to lock screen and Control Center.
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        let artwork = artworkCache[song.id]
        NowPlayingManager.shared.updateNowPlaying(
            song: song,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying,
            artworkImage: artwork
        )
    }
    
    /// Asynchronously downloads and caches artwork for lockscreen display.
    private func loadArtwork(from url: URL, for songId: String) {
        if let cached = artworkCache[songId] {
            updateNowPlayingInfo()
            return
        }
        
        if let sharedCached = ImageCacheManager.shared.image(for: url) {
            artworkCache[songId] = sharedCached
            updateNowPlayingInfo()
            return
        }
        
        Task {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let image = UIImage(data: data) {
                ImageCacheManager.shared.set(image, for: url)
                self.artworkCache[songId] = image
                self.updateNowPlayingInfo()
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    @objc private nonisolated func handleTrackEnded() {
        Task { @MainActor in
            guard !self.isAdvancingTrack else { return }
            self.isAdvancingTrack = true
            self.next()
        }
    }
    
    @objc private nonisolated func handleDidEnterBackground() {
        Task { @MainActor in
            if self.isPlaying {
                self.configureAudioSession()
                self.player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
                if self.player?.rate == 0 {
                    self.player?.play()
                }
                self.updateNowPlayingInfo()
            }
        }
    }
    
    @objc private nonisolated func handleWillEnterForeground() {
        Task { @MainActor in
            self.updateNowPlayingInfo()
        }
    }
    
    @objc private nonisolated func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        Task { @MainActor in
            switch type {
            case .began:
                self.pause()
            case .ended:
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.resume()
                    }
                }
            @unknown default:
                break
            }
        }
    }
    
    @objc private nonisolated func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        Task { @MainActor in
            if reason == .oldDeviceUnavailable {
                self.pause()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
