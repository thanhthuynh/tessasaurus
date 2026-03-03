//
//  PhotoWallViewModel.swift
//  Tessasaurus
//

import SwiftUI
import CloudKit
import Observation

@Observable
@MainActor
final class PhotoWallViewModel {
    var photos: [Photo] = []
    var isLoading = false
    var isUploading = false
    var uploadProgress: Double = 0
    var errorMessage: String?
    var showError = false
    var isUploaderMode = false
    private(set) var loadedImageIDs: Set<UUID> = []

    private let cloudService = CloudKitPhotoService.shared
    private let storageService = PhotoStorageService.shared
    private let cacheService = ImageCacheService.shared

    // Key for storing uploader mode preference
    private let uploaderModeKey = "isUploaderMode"

    init() {
        isUploaderMode = UserDefaults.standard.bool(forKey: uploaderModeKey)
        loadCachedPhotos()
        // Start pre-warming memory cache from disk immediately
        Task { [weak self] in await self?.preloadImages() }
    }

    // MARK: - Public Methods

    func loadPhotos() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            // Check iCloud account status
            let status = try await cloudService.checkAccountStatus()
            guard status == .available else {
                // No iCloud account — silently fall back to cached photos
                isLoading = false
                return
            }

            // Fetch from CloudKit
            let cloudPhotos = try await cloudService.fetchAllPhotos()

            // Update local cache
            try? storageService.savePhotosMetadata(cloudPhotos)

            photos = cloudPhotos

            // Subscribe to changes if not already (non-throwing, logs errors internally)
            await cloudService.subscribeToChanges()

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func uploadPhotos(images: [(UIImage, String?, BubbleSize)]) async {
        guard !isUploading else { return }
        isUploading = true
        uploadProgress = 0

        let totalCount = Double(images.count)

        for (index, (image, caption, size)) in images.enumerated() {
            do {
                let photo = try await cloudService.uploadPhoto(
                    image: image,
                    caption: caption,
                    bubbleSize: size
                )

                photos.insert(photo, at: 0)

                // Cache the image
                cacheService.setImage(image, forKey: photo.id.uuidString)
                loadedImageIDs.insert(photo.id)

            } catch {
                handleError(error)
            }

            uploadProgress = Double(index + 1) / totalCount
        }

        // Save updated metadata
        try? storageService.savePhotosMetadata(photos)

        isUploading = false
        uploadProgress = 0
    }

    func deletePhoto(_ photo: Photo) async {
        do {
            try await cloudService.deletePhoto(photo)

            photos.removeAll { $0.id == photo.id }

            // Remove from cache
            cacheService.removeImage(forKey: photo.id.uuidString)

            // Save updated metadata
            try? storageService.savePhotosMetadata(photos)

        } catch {
            handleError(error)
        }
    }

    func image(for photo: Photo) -> UIImage? {
        // Touch observed set so SwiftUI re-renders when new images load
        _ = loadedImageIDs.contains(photo.id)
        return cacheService.image(forKey: photo.id.uuidString)
    }

    func loadImageAsync(for photo: Photo) async -> UIImage? {
        // Check memory cache
        if let cached = cacheService.image(forKey: photo.id.uuidString) {
            return cached
        }

        // Check local storage on background thread
        let fileName = photo.localFileName
        let storageService = self.storageService
        let diskImage: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let fileName else { return nil }
            return storageService.loadImage(fileName: fileName)
        }.value

        if let diskImage {
            cacheService.setImage(diskImage, forKey: photo.id.uuidString)
            loadedImageIDs.insert(photo.id)
            return diskImage
        }

        // Fallback: fetch from CloudKit
        do {
            if let cloudImage = try await cloudService.fetchImageForPhoto(photo) {
                cacheService.setImage(cloudImage, forKey: photo.id.uuidString)
                loadedImageIDs.insert(photo.id)
                return cloudImage
            }
        } catch {
            // Non-fatal — photo stays as placeholder
        }

        return nil
    }

    func preloadImages() async {
        let unloaded = photos.filter { image(for: $0) == nil }
        let maxConcurrent = 4

        for batch in stride(from: 0, to: unloaded.count, by: maxConcurrent) {
            let end = min(batch + maxConcurrent, unloaded.count)
            let slice = unloaded[batch..<end]

            await withTaskGroup(of: Void.self) { group in
                for photo in slice {
                    group.addTask {
                        _ = await self.loadImageAsync(for: photo)
                    }
                }
            }
        }
    }

    func toggleUploaderMode() {
        isUploaderMode.toggle()
        UserDefaults.standard.set(isUploaderMode, forKey: uploaderModeKey)
    }

    func refresh() async {
        await loadPhotos()
        await preloadImages()
    }

    // MARK: - Private Methods

    private func loadCachedPhotos() {
        let cached = storageService.loadPhotosMetadata()
        if !cached.isEmpty {
            photos = cached
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    private func cloudKitError(for status: CKAccountStatus) -> CloudKitError {
        switch status {
        case .noAccount:
            return .noAccount
        case .restricted:
            return .restricted
        case .temporarilyUnavailable:
            return .temporarilyUnavailable
        default:
            return .unknown
        }
    }
}
