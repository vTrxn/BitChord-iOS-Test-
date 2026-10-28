import Foundation
import MediaPlayer
import UIKit

/// Configures iOS lockscreen, CarPlay, and Dynamic Island playback metadata and command listeners.
final class NowPlayingManager {
    static let shared = NowPlayingManager()
    
    private init() {}
    
    /// Registers target action handlers on `MPRemoteCommandCenter` for remote playback actions.
    func setupRemoteCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onTogglePlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            onTogglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            onNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            onPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                onSeek(positionEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    /// Updates the dictionary in `MPNowPlayingInfoCenter.default().nowPlayingInfo`.
    func updateNowPlaying(
        song: Song,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        artworkImage: UIImage? = nil
    ) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        if let album = song.albumName {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : Double(song.durationSeconds)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let image = artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
