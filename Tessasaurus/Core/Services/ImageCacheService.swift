//
//  ImageCacheService.swift
//  Tessasaurus
//

import UIKit
import ImageIO

/// Thread safety: `@unchecked Sendable` is safe here because all mutable state is held in
/// `NSCache` instances, which are documented as thread-safe for individual get/set operations.
final class ImageCacheService: @unchecked Sendable {
    static let shared = ImageCacheService()

    /// Separate caches prevent full-res images from evicting all thumbnails.
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fullResCache = NSCache<NSString, UIImage>()

    private init() {
        thumbnailCache.countLimit = 200
        thumbnailCache.totalCostLimit = 30 * 1024 * 1024 // 30 MB for thumbnails

        fullResCache.countLimit = 10
        fullResCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB for full-res

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMemoryWarning() {
        thumbnailCache.removeAllObjects()
        fullResCache.removeAllObjects()
    }

    func image(forKey key: String) -> UIImage? {
        fullResCache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = imageCost(image)
        fullResCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeImage(forKey key: String) {
        fullResCache.removeObject(forKey: key as NSString)
        thumbnailCache.removeObject(forKey: "thumb_\(key)" as NSString)
    }

    func setThumbnail(_ image: UIImage, forKey key: String, maxDimension: CGFloat = 300) {
        let thumbnailKey = "thumb_\(key)"
        let downsampled = downsample(image, maxDimension: maxDimension)
        let cost = imageCost(downsampled)
        thumbnailCache.setObject(downsampled, forKey: thumbnailKey as NSString, cost: cost)
    }

    func thumbnail(forKey key: String) -> UIImage? {
        thumbnailCache.object(forKey: "thumb_\(key)" as NSString)
    }

    func clearCache() {
        thumbnailCache.removeAllObjects()
        fullResCache.removeAllObjects()
    }

    private func imageCost(_ image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    }

    /// Downsample directly from compressed Data using ImageIO — never allocates the full bitmap.
    static func downsampleFromData(_ data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
