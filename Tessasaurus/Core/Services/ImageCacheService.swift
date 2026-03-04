//
//  ImageCacheService.swift
//  Tessasaurus
//

import UIKit

final class ImageCacheService {
    static let shared = ImageCacheService()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB (thumbnails are smaller)

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
        cache.removeAllObjects()
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func setThumbnail(_ image: UIImage, forKey key: String, maxDimension: CGFloat = 300) {
        let thumbnailKey = "thumb_\(key)"
        let downsampled = downsample(image, maxDimension: maxDimension)
        let cost = Int(downsampled.size.width * downsampled.size.height * downsampled.scale * downsampled.scale * 4)
        cache.setObject(downsampled, forKey: thumbnailKey as NSString, cost: cost)
    }

    func thumbnail(forKey key: String) -> UIImage? {
        cache.object(forKey: "thumb_\(key)" as NSString)
    }

    func clearCache() {
        cache.removeAllObjects()
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
