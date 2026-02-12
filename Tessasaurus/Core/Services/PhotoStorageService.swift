//
//  PhotoStorageService.swift
//  Tessasaurus
//

import UIKit

final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let fileManager = FileManager.default
    private let photosDirectory: URL

    private init() {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        photosDirectory = cacheDirectory.appendingPathComponent("Photos", isDirectory: true)

        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
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

    func generateFileName(for photoID: UUID) -> String {
        "\(photoID.uuidString).jpg"
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
