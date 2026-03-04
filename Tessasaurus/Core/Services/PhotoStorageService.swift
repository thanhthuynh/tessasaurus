//
//  PhotoStorageService.swift
//  Tessasaurus
//

import UIKit

final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let fileManager = FileManager.default
    private let photosDirectory: URL
    private let thumbnailsDirectory: URL

    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        photosDirectory = documentsDirectory.appendingPathComponent("Photos", isDirectory: true)
        thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)

        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        }

        migrateFromCachesIfNeeded()
    }

    private func migrateFromCachesIfNeeded() {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let oldDirectory = cacheDirectory.appendingPathComponent("Photos", isDirectory: true)

        guard fileManager.fileExists(atPath: oldDirectory.path) else { return }

        if let files = try? fileManager.contentsOfDirectory(at: oldDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                let destination = photosDirectory.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.moveItem(at: file, to: destination)
                }
            }
        }

        // Only remove old directory if it's empty (all files migrated successfully)
        if let remaining = try? fileManager.contentsOfDirectory(at: oldDirectory, includingPropertiesForKeys: nil),
           remaining.isEmpty {
            try? fileManager.removeItem(at: oldDirectory)
        }
    }

    func saveImage(_ image: UIImage, fileName: String) throws {
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw PhotoStorageError.compressionFailed
        }

        try data.write(to: fileURL)
    }

    func loadImage(fileName: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    func imageExists(fileName: String) -> Bool {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func deleteImage(fileName: String) throws {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func deleteAllImages() throws {
        let contents = try fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func saveThumbnail(_ image: UIImage, fileName: String, maxDimension: CGFloat = 300) throws {
        let downsampled = downsampleImage(image, maxDimension: maxDimension)
        let fileURL = thumbnailsDirectory.appendingPathComponent(fileName)
        guard let data = downsampled.jpegData(compressionQuality: 0.7) else {
            throw PhotoStorageError.compressionFailed
        }
        try data.write(to: fileURL)
    }

    func loadThumbnail(fileName: String) -> UIImage? {
        let fileURL = thumbnailsDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    func generateFileName(for photoID: UUID) -> String {
        "\(photoID.uuidString).jpg"
    }

    private func downsampleImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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

    // MARK: - Photo Metadata Persistence

    private var metadataURL: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("photos_metadata.json")
    }

    func savePhotosMetadata(_ photos: [Photo]) throws {
        let data = try JSONEncoder().encode(photos)
        try data.write(to: metadataURL)
    }

    func loadPhotosMetadata() -> [Photo] {
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let photos = try? JSONDecoder().decode([Photo].self, from: data) else {
            return []
        }
        return photos
    }
}

enum PhotoStorageError: Error, LocalizedError {
    case compressionFailed
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .saveFailed:
            return "Failed to save image to disk"
        case .loadFailed:
            return "Failed to load image from disk"
        }
    }
}
