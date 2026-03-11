import Foundation
import SkipFuse

private let logger = Log(category: "ImageCache")

public class ImageCacheService: @unchecked Sendable {
    public static let shared = ImageCacheService()

    private let directoryName = "mealie_image_cache"

    private init() {}

    // MARK: - Cache Lookup

    public func cachedImagePath(recipeId: String, imageType: String) -> String? {
        guard let dir = cacheDirectory() else { return nil }
        let filename = sanitizeFilename(recipeId: recipeId, imageType: imageType)
        let filePath = dir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: filePath.path) {
            return filePath.path
        }
        return nil
    }

    // MARK: - Save to Cache

    public func cacheImage(data: Data, recipeId: String, imageType: String) {
        guard let dir = cacheDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = sanitizeFilename(recipeId: recipeId, imageType: imageType)
        let filePath = dir.appendingPathComponent(filename)
        do {
            try data.write(to: filePath)
        } catch {
            logger.error("Failed to cache image for \(recipeId): \(error)")
        }
    }

    // MARK: - Remove Cached Images

    public func removeCachedImages(recipeId: String) {
        guard let dir = cacheDirectory() else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files where file.hasPrefix(recipeId) {
            try? fm.removeItem(at: dir.appendingPathComponent(file))
        }
    }

    // MARK: - Preload Thumbnails

    public func preloadThumbnails(recipes: [RecipeSummary]) async {
        guard MealieAPI.shared.isConfigured else { return }

        for recipe in recipes {
            guard let recipeId = recipe.id else { continue }
            let imageType = "tiny-original.webp"
            if cachedImagePath(recipeId: recipeId, imageType: imageType) != nil { continue }

            let urlString = MealieAPI.shared.recipeImageURL(recipeId: recipeId, imageType: imageType)
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResp = response as? HTTPURLResponse,
                   (200...299).contains(httpResp.statusCode),
                   !data.isEmpty {
                    cacheImage(data: data, recipeId: recipeId, imageType: imageType)
                }
            } catch {
                // Silently skip preload failures
            }
        }
    }

    // MARK: - Cache Detail Image

    public func cacheDetailImage(recipeId: String) async {
        guard MealieAPI.shared.isConfigured else { return }

        let imageType = "min-original.webp"
        if cachedImagePath(recipeId: recipeId, imageType: imageType) != nil { return }

        let urlString = MealieAPI.shared.recipeImageURL(recipeId: recipeId, imageType: imageType)
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse,
               (200...299).contains(httpResp.statusCode),
               !data.isEmpty {
                cacheImage(data: data, recipeId: recipeId, imageType: imageType)
            }
        } catch {
            logger.error("Failed to cache detail image for \(recipeId): \(error)")
        }
    }

    // MARK: - Clear

    public func clearAll() {
        guard let dir = cacheDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Private

    private func sanitizeFilename(recipeId: String, imageType: String) -> String {
        let sanitized = imageType
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return "\(recipeId)_\(sanitized)"
    }

    private func cacheDirectory() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches.appendingPathComponent(directoryName)
    }
}
