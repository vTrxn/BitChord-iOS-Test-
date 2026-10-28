import SwiftUI

struct SettingsView: View {
    @ObservedObject private var instanceManager = InstanceManager.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var player = AudioPlayerManager.shared
    
    @AppStorage(AppConstants.StorageKey.streamQuality)
    private var selectedQuality: StreamQuality = .high
    
    @State private var showingCustomInstanceAlert: Bool = false
    @State private var customInstanceURL: String = ""
    @State private var showingClearCacheAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                // Audio Quality Section
                Section("Playback Quality") {
                    Picker("Streaming Quality", selection: $selectedQuality) {
                        ForEach(StreamQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Server Instances Section
                Section {
                    ForEach(instanceManager.availableInstances, id: \.self) { instance in
                        Button {
                            instanceManager.setInstance(instance)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instance.replacingOccurrences(of: "https://", with: ""))
                                        .foregroundColor(.primary)
                                    if instance == instanceManager.activeInstance {
                                        Text("Active Server")
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Spacer()
                                if instance == instanceManager.activeInstance {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    
                    Button {
                        customInstanceURL = ""
                        showingCustomInstanceAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Custom Server Instance")
                        }
                        .foregroundColor(.accentColor)
                        .frame(minHeight: 44)
                    }
                    
                    Button {
                        Task {
                            await instanceManager.refreshInstances()
                        }
                    } label: {
                        HStack {
                            if instanceManager.isCheckingHealth {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh & Check Server Health")
                        }
                        .foregroundColor(.primary)
                        .frame(minHeight: 44)
                    }
                } header: {
                    Text("Music Audio Backend")
                } footer: {
                    Text("BitChord dynamically routes audio requests through verified, privacy-preserving nodes.")
                }
                
                // Storage Section
                Section("Storage & Offline") {
                    HStack {
                        Text("Downloaded Tracks")
                        Spacer()
                        Text("\(downloads.downloadedSongs.count) songs")
                            .foregroundColor(.secondary)
                    }
                    
                    if !downloads.downloadedSongs.isEmpty {
                        Button(role: .destructive) {
                            showingClearCacheAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete All Offline Downloads")
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Application")
                        Spacer()
                        Text(AppConstants.appName)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("License")
                        Spacer()
                        Text("GNU GPL v3.0")
                            .foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://github.com/kushagrasinghx/BitChord")!) {
                        HStack {
                            Text("Original BitChord Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if player.currentSong != nil {
                    Color.clear.frame(height: 68)
                }
            }
            .navigationTitle("Settings")
            .alert("Add Custom Instance", isPresented: $showingCustomInstanceAlert) {
                TextField("https://instance.example.com", text: $customInstanceURL)
                    .autocapitalization(.none)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if !customInstanceURL.isEmpty {
                        instanceManager.setInstance(customInstanceURL)
                    }
                }
            }
            .alert("Clear Downloads?", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    for song in downloads.downloadedSongs {
                        downloads.removeDownload(songId: song.id)
                    }
                }
            } message: {
                Text("This will permanently remove all downloaded songs from your device storage.")
            }
        }
    }
}
