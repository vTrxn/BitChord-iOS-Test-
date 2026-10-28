import SwiftUI

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 1024 * 1024 * 60 // 60MB
    }
    
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage?
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            if let image = uiImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        if let cached = ImageCacheManager.shared.image(for: url) {
            self.uiImage = cached
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloaded = UIImage(data: data) {
                ImageCacheManager.shared.set(downloaded, for: url)
                await MainActor.run {
                    self.uiImage = downloaded
                }
            }
        } catch {
            // Keep placeholder on failure
        }
    }
}
