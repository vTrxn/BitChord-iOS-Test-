# BitChord iOS: Architecture and Technical Reference

This document outlines the software architecture, concurrency model, audio subsystem, and networking resilience strategies implemented in BitChord iOS.

---

## 1. System Overview

BitChord iOS is designed using the **Model-View-ViewModel (MVVM)** architectural pattern combined with observable singletons for cross-cutting hardware concerns (audio session, remote commands, local storage).

```
[ SwiftUI Views ]
       │
       ▼
[ ViewModels / Observable Managers ] ───► [ Storage Layer (UserDefaults / Disk) ]
       │
       ├─────────────────────────────────► [ CoreAudio Subsystem (AVPlayer) ]
       │                                            │
       ▼                                            ▼
[ Services Layer (HTTP / JSON) ]         [ MediaPlayer (Lockscreen & Remote) ]
```

---

## 2. Core Audio Subsystem

### Audio Session Configuration
Background playback requires explicit audio session activation with the `.playback` category before starting any player items.

* **File:** `BitChord/CoreAudio/AudioPlayerManager.swift`
* **Configuration:**
  ```swift
  let session = AVAudioSession.sharedInstance()
  try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
  try session.setActive(true)
  ```
* **Required Entitlement:** `UIBackgroundModes: ["audio"]` in `Info.plist`.

### Lockscreen and Remote Command Center
`NowPlayingManager.swift` binds `MPRemoteCommandCenter` commands to player actions:
* `playCommand` / `pauseCommand` / `togglePlayPauseMusicCommand`
* `nextTrackCommand` / `previousTrackCommand`
* `changePlaybackPositionCommand` (scrubbing from lockscreen or Apple Watch)

Track duration, elapsed time, title, artist, and high-resolution album art are pushed to `MPNowPlayingInfoCenter.default().nowPlayingInfo`. Artwork is fetched asynchronously and cached to avoid stalling the main thread.

### Interruptions and Route Changes
The player subscribes to system notifications:
* `AVAudioSession.interruptionNotification`: Automatically pauses audio when receiving a phone call or Siri trigger, and resumes if the interruption ends with `.shouldResume`.
* `AVAudioSession.routeChangeNotification`: Automatically pauses playback when headphones or Bluetooth devices disconnect (`.oldDeviceUnavailable`).

---

## 3. Network and Stream Resolution

YouTube Music audio is extracted using open Invidious instances without requiring official Google API keys or OAuth authentication:

```
User Query ──► MusicSearchService ──► Active Invidious Node (/api/v1/search)
                                               │
Track Tap  ──► AudioStreamService  ──► Active Invidious Node (/api/v1/videos)
                                               │
                                               ▼
                                      Extracts M4A stream
                                               │
                                               ▼
                                      AVPlayer / DownloadManager
```

### Instance Failover Strategy
Public Invidious nodes can experience rate limiting or downtime. BitChord implements a multi-tier fallback:
1. Try the user's selected active instance.
2. If the request times out or returns HTTP 4xx/5xx, sequentially query fallback nodes from `AppConstants.defaultInstances`.
3. Provide dynamic health monitoring via `InstanceManager.refreshInstances()`, which reads `https://api.invidious.io/instances.json?sort_by=health`.

### Formats and Codecs
`AudioStreamService` filters the `adaptiveFormats` array specifically for `audio/mp4` MIME types (M4A container with AAC audio). M4A is hardware-accelerated on Apple silicon, reducing battery drain and memory pressure compared to software-decoded Opus/WebM streams.

---

## 4. Lyrics Synchronization Engine

Lyrics are retrieved from **LRCLIB** (`https://lrclib.net`):
1. **Sanitization:** Track titles are cleaned using regular expressions to strip YouTube tags such as `(Official Video)` or `[Audio]`.
2. **Exact Lookup:** Queries `/api/get?artist_name=...&track_name=...&duration=...`.
3. **Fuzzy Search Fallback:** If exact lookup yields no results, queries `/api/search?q=...`.
4. **Timestamp Parsing:** `ParsedLyrics.parseLRC` matches timestamp tags (`[mm:ss.xx]`) with regular expressions, converting them into floating-point seconds.
5. **UI Synchronization:** `AudioPlayerManager` polls playback progress every 250 milliseconds and computes `activeLyricIndex`. `LyricsSheetView` uses SwiftUI's `ScrollViewReader` to automatically scroll the active line to the center of the viewport.

---

## 5. Local Storage and Sandbox Security

BitChord stores user preferences and downloaded tracks in the app's sandboxed filesystem:
* **Playlists and Favorites:** Serialized to JSON and persisted via `UserDefaults`.
* **Offline Audio Files:** Saved in `Application Support/BitChordDownloads/<id>.m4a`.
* **Download Verification:** At app launch, `DownloadManager` verifies that each indexed audio file actually exists on disk, pruning orphan records.

---

## 6. User Interface Guidelines

In compliance with design standards:
* **No Glassmorphism:** All surfaces use solid system backgrounds (`.systemGroupedBackground`, `.secondarySystemGroupedBackground`) with intentional contrast ratios.
* **Accessibility:** Text adheres to WCAG AA minimum contrast (4.5:1 for body copy).
* **Tap Targets:** Interactive elements have a minimum frame dimension of 44x44 points.
* **Three-State Views:** All network data views (`HomeView`, `SearchView`, `LibraryView`) explicitly handle Loading, Empty, and Error states.
