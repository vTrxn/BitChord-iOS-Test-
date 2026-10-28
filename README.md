# BitChord for iOS

**BitChord iOS** is a free, open-source music streaming client for iPhone and iPad inspired by the original Android project [BitChord](https://github.com/kushagrasinghx/BitChord).

Built natively in **Swift and SwiftUI**, it provides ad-free music playback, background streaming, lock-screen controls, synchronized karaoke lyrics, offline downloads, and local playlists using a clean flat design.

Repository: [https://github.com/vTrxn/BitChord-iOS-Test-](https://github.com/vTrxn/BitChord-iOS-Test-)
CI/CD Pipeline: [![Build BitChord iOS IPA](https://github.com/vTrxn/BitChord-iOS-Test-/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/vTrxn/BitChord-iOS-Test-/actions/workflows/build-ipa.yml)
Latest Successful IPA Build: [GitHub Actions Run 40627457161](https://github.com/vTrxn/BitChord-iOS-Test-/actions/runs/40627457161)

---

## Features

* **Ad-Free Music Playback:** Stream tracks directly without interruptions or audio ads.
* **Background Audio and Lock Screen:** Native `AVAudioSession` integration supports continuous playback with the screen locked, car Bluetooth systems, Dynamic Island, and lock-screen widget controls (`MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`).
* **Synchronized Live Lyrics (Karaoke):** Real-time lyrics powered by LRCLIB with millisecond synchronization, auto-scrolling to the active phrase, and tap-to-seek functionality.
* **Offline Downloads:** Download any track in `.m4a` format directly to device storage for offline playback.
* **Library and Playlists:** Manage Liked Songs, custom playlists, and recent history locally on your device.
* **Flat Design:** Built strictly following iOS Human Interface Guidelines and WCAG AA contrast standards with solid surfaces and no glassmorphism.
* **Dynamic Backend Routing:** Configurable Invidious audio instances with automatic health checking and failover.

---

## Architecture and Source Code Overview

The codebase is organized into modular layers:

| Layer | Directory | Purpose |
| :--- | :--- | :--- |
| **App** | `BitChord/App/` | App lifecycle (`BitChordApp.swift`) and global configuration (`AppConstants.swift`). |
| **Models** | `BitChord/Models/` | Data structures for `Song`, `Playlist`, `LyricLine`, and `StreamQuality`. |
| **CoreAudio** | `BitChord/CoreAudio/` | `AudioPlayerManager` (AVPlayer, background session) and `NowPlayingManager` (lockscreen). |
| **Services** | `BitChord/Services/` | `MusicSearchService`, `AudioStreamService`, `LyricsService`, `InstanceManager`, and `DownloadManager`. |
| **Storage** | `BitChord/Storage/` | `FavoritesManager` (Liked songs, playlists, recently played). |
| **Views** | `BitChord/Views/` | SwiftUI views for Discover, Search, Library, Settings, Full Player, Mini Player, and Lyrics. |
| **Resources** | `BitChord/Resources/` | `Info.plist` with background audio entitlements and asset catalogs. |

For deep technical details on concurrency, audio pipelines, and network failover, consult [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Installation and Sideloading

Because BitChord streams music outside official App Store restrictions, it is installed via sideloading (no jailbreak required).

### Method 1: Automated Cloud Build via GitHub Actions (Recommended)
1. Fork or push this repository to your GitHub account:
   ```bash
   git remote add origin https://github.com/vTrxn/BitChord-iOS-Test-.git
   git branch -M main
   git push -u origin main
   ```
2. In your repository on GitHub, go to the **Actions** tab.
3. Select the workflow **Build BitChord iOS IPA** and click **Run workflow**.
4. GitHub's macOS virtual machines compile the Swift codebase and output an unsigned `BitChord.ipa` artifact under the completed run.
5. Download the `.ipa` directly to your computer or iPhone.

### Method 2: Sideloading with SideStore or AltStore
1. Download **[SideStore](https://sidestore.io/)** or **[AltStore](https://altstore.io/)** onto your device.
2. In SideStore or AltStore, tap the `+` button in the top corner.
3. Select `BitChord.ipa`.
4. Sign in with your Apple ID to sign and install the app.
5. On your iPhone, go to **Settings > General > VPN & Device Management**, tap your developer certificate, and tap **Trust**.

### Method 3: Sideloading with Sideloadly (Windows and macOS)
1. Download and install **[Sideloadly](https://sideloadly.io/)**.
2. Connect your iPhone to your PC via USB cable.
3. Drag `BitChord.ipa` into Sideloadly, enter your Apple ID email, and click **Start**.
4. Trust the certificate in your iPhone's device settings.

### Method 4: Opening Directly in Xcode (macOS)
1. Clone this repository onto your Mac:
   ```bash
   git clone https://github.com/vTrxn/BitChord-iOS-Test-.git
   cd BitChord-iOS-Test-
   ```
2. Open `BitChord.xcodeproj` in Xcode 15 or newer.
3. Select your development team under **Signing & Capabilities**.
4. Connect your iPhone, select it as the run target, and press `Cmd + R` to build and install.

---

## Contributing

Review [CONTRIBUTING.md](CONTRIBUTING.md) for code style guidelines, antislop design rules, and pull request procedures.

---

## License

This project is licensed under the [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
