import SwiftUI

/// In-memory image caching layer backed by NSCache with a 60MB limit.
final class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 1024 * 1024 * 60
    }
    
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// Asynchronous image view that checks memory cache before issuing network requests.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage?
    
    var body: some View {
        ZStack {
            if let image = uiImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage(for: url)
        }
    }
    
    private func loadImage(for targetURL: URL?) async {
        guard let targetURL = targetURL else {
            await MainActor.run { self.uiImage = nil }
            return
        }
        
        if let cached = ImageCacheManager.shared.image(for: targetURL) {
            await MainActor.run { self.uiImage = cached }
            return
        }
        
        await MainActor.run { self.uiImage = nil }
        
        var request = URLRequest(url: targetURL)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let downloaded = UIImage(data: data) {
                ImageCacheManager.shared.set(downloaded, for: targetURL)
                await MainActor.run {
                    self.uiImage = downloaded
                }
                return
            }
        } catch {
            // Try fallback below if applicable
        }
        
        // Fallback to mqdefault if hqdefault failed
        let absolute = targetURL.absoluteString
        if absolute.contains("hqdefault.jpg"),
           let fallbackURL = URL(string: absolute.replacingOccurrences(of: "hqdefault.jpg", with: "mqdefault.jpg")) {
            if let cached = ImageCacheManager.shared.image(for: fallbackURL) {
                await MainActor.run { self.uiImage = cached }
                return
            }
            if let (data, _) = try? await URLSession.shared.data(from: fallbackURL),
               let downloaded = UIImage(data: data) {
                ImageCacheManager.shared.set(downloaded, for: targetURL)
                await MainActor.run {
                    self.uiImage = downloaded
                }
            }
        }
    }
}
