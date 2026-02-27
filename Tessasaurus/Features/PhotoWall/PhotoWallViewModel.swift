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
        Task { await preloadImages() }
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
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                if let fileName = photo.localFileName,
                   let image = self.storageService.loadImage(fileName: fileName) {
                    DispatchQueue.main.async {
                        self.cacheService.setImage(image, forKey: photo.id.uuidString)
                        self.loadedImageIDs.insert(photo.id)
                    }
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func preloadImages() async {
        let unloaded = photos.filter { image(for: $0) == nil }
        await withTaskGroup(of: Void.self) { group in
            for photo in unloaded {
                group.addTask {
                    let _ = await self.loadImageAsync(for: photo)
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
