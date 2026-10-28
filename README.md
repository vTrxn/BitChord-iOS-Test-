# BitChord for iOS

**BitChord iOS** is a free, open-source music streaming client for iPhone and iPad inspired by the design and capabilities of the original Android project [BitChord](https://github.com/kushagrasinghx/BitChord).

Built from the ground up in **Swift and SwiftUI**, it delivers ad-free music playback, background streaming, lock-screen controls, synchronized karaoke lyrics, offline downloads, and local playlists using a clean flat design.

---

## Key Features

* **Ad-Free Music Playback:** Stream tracks directly without interruptions or audio ads.
* **Background Audio & Lockscreen:** Native `AVAudioSession` integration supports seamless playback with the screen turned off, car Bluetooth controls, Dynamic Island, and lock-screen widget controls (`MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`).
* **Synchronized Live Lyrics (Karaoke):** Real-time lyrics powered by LRCLIB with millisecond synchronization, auto-scrolling to the active phrase, and tap-to-seek functionality.
* **Offline Downloads:** Download any track in `.m4a` format to your device sandbox for playback without an internet connection.
* **Library & Playlists:** Manage Liked Songs, custom playlists, and recent history locally on your device.
* **Flat & Accessible Design:** Built strictly following iOS Human Interface Guidelines and WCAG AA contrast standards with no visual clutter.
* **Dynamic Backend Routing:** Configurable Invidious/Audio instances with automatic health checking and failover.

---

## Project Architecture

```text
BitChord-iOS/
├── .github/
│   └── workflows/
│       └── build-ipa.yml              # Automated cloud compilation
├── BitChord/
│   ├── App/
│   │   ├── BitChordApp.swift          # App entrypoint
│   │   └── AppConstants.swift         # Global configuration and endpoints
│   ├── Models/
│   │   ├── Song.swift                 # Track model and duration formatters
│   │   ├── Playlist.swift             # Custom playlist data structure
│   │   ├── LyricLine.swift            # LRC timestamp parser
│   │   └── StreamQuality.swift        # Bitrate quality settings
│   ├── Services/
│   │   ├── InstanceManager.swift      # Dynamic server instance failover
│   │   ├── MusicSearchService.swift   # Search and trending charts
│   │   ├── AudioStreamService.swift   # Audio stream resolution
│   │   ├── LyricsService.swift        # LRCLIB API client
│   │   └── DownloadManager.swift      # Offline file caching engine
│   ├── CoreAudio/
│   │   ├── AudioPlayerManager.swift   # AVPlayer engine and queue
│   │   └── NowPlayingManager.swift    # Lockscreen metadata and commands
│   ├── Storage/
│   │   └── FavoritesManager.swift     # Local persistent storage
│   ├── Views/
│   │   ├── MainTabView.swift          # Root navigation tabs
│   │   ├── Components/
│   │   │   ├── StateViews.swift       # Loading, Empty, and Error states
│   │   │   ├── SongRowView.swift      # Track item with context actions
│   │   │   ├── CachedAsyncImage.swift # In-memory image caching
│   │   │   └── ProgressBarView.swift  # Scrubber slider
│   │   ├── Home/
│   │   │   └── HomeView.swift         # Trending charts and recents
│   │   ├── Search/
│   │   │   └── SearchView.swift       # Catalog search and history
│   │   ├── Library/
│   │   │   ├── LibraryView.swift      # Favorites and playlists
│   │   │   └── PlaylistDetailView.swift
│   │   ├── Player/
│   │   │   ├── MiniPlayerView.swift   # Persistent docked bar
│   │   │   ├── FullPlayerView.swift   # Fullscreen player sheet
│   │   │   └── LyricsSheetView.swift  # Live synchronized lyrics
│   │   └── Settings/
│   │       └── SettingsView.swift     # Audio quality and server configuration
│   └── Resources/
│       ├── Info.plist                 # Permissions and background modes
│       └── Assets.xcassets            # Icons and app accent
├── project.yml                        # XcodeGen project specification
├── BitChord.xcodeproj/                # Pre-configured Xcode project
└── generate_project.py                # Deterministic pbxproj generator
```

---

## Installation & Sideloading on iOS

Because BitChord streams music outside official App Store restrictions, it is installed via sideloading (no jailbreak required).

### Method 1: Automated IPA Build via GitHub Actions (Recommended if on Windows/Linux)
1. Fork or push this repository to your GitHub account.
2. Go to the **Actions** tab in your GitHub repository.
3. Select **Build BitChord iOS IPA** and click **Run workflow**.
4. GitHub's macOS virtual machines will compile the Swift codebase and output an unsigned `BitChord.ipa` artifact under the completed run.
5. Download the `.ipa` directly to your computer or iPhone.

### Method 2: Sideloading with SideStore or AltStore
1. Download **[SideStore](https://sidestore.io/)** or **[AltStore](https://altstore.io/)** onto your device.
2. In SideStore/AltStore, tap the `+` button in the top corner.
3. Select `BitChord.ipa`.
4. Sign in with your Apple ID to sign and install the app.
5. On your iPhone, go to **Settings > General > VPN & Device Management**, tap your developer certificate, and tap **Trust**.

### Method 3: Sideloading with Sideloadly (Windows/Mac)
1. Download and install **[Sideloadly](https://sideloadly.io/)**.
2. Connect your iPhone to your PC via USB cable.
3. Drag `BitChord.ipa` into Sideloadly, enter your Apple ID email, and click **Start**.
4. Trust the certificate in your iPhone's device settings.

### Method 4: Opening Directly in Xcode (macOS)
1. Clone this repository onto your Mac:
   ```bash
   git clone https://github.com/your-username/BitChord-iOS.git
   cd BitChord-iOS
   ```
2. Open `BitChord.xcodeproj` in Xcode.
3. Select your development team under **Signing & Capabilities**.
4. Connect your iPhone, select it as the run target, and press `Cmd + R` to build and install.

---

## License

This project is licensed under the [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
