//
//  PhotoWallViewModel.swift
//  Tessasaurus
//

import SwiftUI
import Observation
import os

struct UploadResult {
    let successCount: Int
    let failureCount: Int
}

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
    private let photoService = FirebasePhotoService.shared
    private let storageService = PhotoStorageService.shared
    private let cacheService = ImageCacheService.shared

    private static let logger = Logger(subsystem: "personal.thanhhuynh.Tessasaurus", category: "PhotoWall")

    // Key for storing uploader mode preference
    private let uploaderModeKey = "isUploaderMode"

    private var needsRefreshAfterUpload = false
    private var inFlightLoads: [UUID: Task<UIImage?, Never>] = [:]
    private var listenerActive = false

    init() {
        isUploaderMode = UserDefaults.standard.bool(forKey: uploaderModeKey)
        loadCachedPhotos()
    }

    // MARK: - Public Methods

    func loadPhotos() async {
        guard !isLoading else { return }

        // Defer loading if upload is in progress
        if isUploading {
            needsRefreshAfterUpload = true
            return
        }

        isLoading = true

        do {
            try await photoService.ensureAuthenticated()

            let fetchedPhotos = try await photoService.fetchAllPhotos()

            // Update local cache
            do {
                try storageService.savePhotosMetadata(fetchedPhotos)
            } catch {
                Self.logger.error("Failed to save photo metadata: \(error.localizedDescription)")
            }

            photos = fetchedPhotos

            // Start real-time listener for delta sync
            startRealtimeSync()

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    func uploadPhotos(images: [(UIImage, String?, BubbleSize)]) async -> UploadResult {
        guard !isUploading else { return UploadResult(successCount: 0, failureCount: 0) }
        isUploading = true
        uploadProgress = 0

        let totalCount = Double(images.count)
        var successCount = 0
        var failureCount = 0

        for (index, (image, caption, size)) in images.enumerated() {
            do {
                let photo = try await photoService.uploadPhoto(
                    image: image,
                    caption: caption,
                    bubbleSize: size
                )

                photos.insert(photo, at: 0)

                // Cache thumbnail for constellation view
                cacheService.setThumbnail(image, forKey: photo.id.uuidString)
                // Also cache full-res for immediate detail view access
                cacheService.setImage(image, forKey: photo.id.uuidString)

                successCount += 1
            } catch {
                failureCount += 1
                handleError(error)
            }

            uploadProgress = Double(index + 1) / totalCount
        }

        // Save updated metadata
        do {
            try storageService.savePhotosMetadata(photos)
        } catch {
            Self.logger.error("Failed to save metadata after upload: \(error.localizedDescription)")
        }

        isUploading = false
        uploadProgress = 0

        // Refresh if a load was deferred during upload
        if needsRefreshAfterUpload {
            needsRefreshAfterUpload = false
            await refresh()
        }

        return UploadResult(successCount: successCount, failureCount: failureCount)
    }

    /// Upload a single photo without managing isUploading/uploadProgress.
    /// Caller is responsible for batch state management.
    func uploadSinglePhoto(image: UIImage, caption: String?, size: BubbleSize) async -> Bool {
        do {
            let photo = try await photoService.uploadPhoto(
                image: image,
                caption: caption,
                bubbleSize: size
            )
            photos.insert(photo, at: 0)
            cacheService.setThumbnail(image, forKey: photo.id.uuidString)
            cacheService.setImage(image, forKey: photo.id.uuidString)
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    /// Cancel an in-progress upload and reset all upload state.
    func cancelUpload() {
        isUploading = false
        uploadProgress = 0
        needsRefreshAfterUpload = false
    }

    /// Save metadata and handle deferred refresh after a batch upload completes.
    func finalizeUpload() async {
        do {
            try storageService.savePhotosMetadata(photos)
        } catch {
            Self.logger.error("Failed to save metadata after finalize: \(error.localizedDescription)")
        }
        isUploading = false
        uploadProgress = 0
        if needsRefreshAfterUpload {
            needsRefreshAfterUpload = false
            await refresh()
        }
    }

    func deletePhoto(_ photo: Photo) async {
        do {
            try await photoService.deletePhoto(photo)

            photos.removeAll { $0.id == photo.id }

            // Remove from cache
            cacheService.removeImage(forKey: photo.id.uuidString)
            cacheService.removeImage(forKey: "thumb_\(photo.id.uuidString)")

            do {
                try storageService.savePhotosMetadata(photos)
            } catch {
                Self.logger.error("Failed to save metadata after delete: \(error.localizedDescription)")
            }
        } catch {
            handleError(error)
        }
    }

    func updateBubbleSize(for photo: Photo, newSize: BubbleSize) async {
        let oldSize = photo.bubbleSize
        // Optimistic update
        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[index].bubbleSize = newSize
        }
        do {
            try await photoService.updatePhotoBubbleSize(photo, newSize: newSize)
            do {
                try storageService.savePhotosMetadata(photos)
            } catch {
                Self.logger.error("Failed to save metadata after bubble size update: \(error.localizedDescription)")
            }
        } catch {
            // Revert on failure
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index].bubbleSize = oldSize
            }
            errorMessage = "Failed to update size"
            showError = true
        }
    }

    func updateCaption(for photo: Photo, newCaption: String?) async {
        let oldCaption = photo.caption
        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[index].caption = newCaption
        }
        do {
            try await photoService.updatePhotoCaption(photo, newCaption: newCaption)
            do {
                try storageService.savePhotosMetadata(photos)
            } catch {
                Self.logger.error("Failed to save metadata after caption update: \(error.localizedDescription)")
            }
        } catch {
            // Revert on failure
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index].caption = oldCaption
            }
            handleError(error)
        }
    }

    /// Returns full-resolution image for detail view (sync, from cache only)
    func fullResolutionImage(for photo: Photo) -> UIImage? {
        return cacheService.image(forKey: photo.id.uuidString)
    }

    func loadImageAsync(for photo: Photo) async -> UIImage? {
        // 1. Check memory cache (thumbnail) — instant return
        if let thumb = cacheService.thumbnail(forKey: photo.id.uuidString) {
            return thumb
        }

        // Deduplicate: if already loading this photo, await the existing task
        if let existing = inFlightLoads[photo.id] {
            return await existing.value
        }

        let photoId = photo.id
        let photoKey = photoId.uuidString
        let fileName = photo.localFileName

        let task = Task<UIImage?, Never> {
            // 2. Check thumbnail disk cache (fast, small files)
            let thumbImage: UIImage? = await Task.detached(priority: .userInitiated) {
                guard let fileName else { return nil }
                return PhotoStorageService.shared.loadThumbnail(fileName: fileName)
            }.value

            if let thumbImage {
                self.cacheService.setThumbnail(thumbImage, forKey: photoKey)
                return thumbImage
            }

            // 3. Check full-res disk, generate thumbnail
            let diskImage: UIImage? = await Task.detached(priority: .userInitiated) {
                guard let fileName else { return nil }
                return PhotoStorageService.shared.loadImage(fileName: fileName)
            }.value

            if let diskImage {
                self.cacheService.setThumbnail(diskImage, forKey: photoKey)
                if let fileName {
                    try? self.storageService.saveThumbnail(diskImage, fileName: fileName)
                }
                // Return directly instead of re-fetching from cache (NSCache can evict immediately)
                return self.cacheService.thumbnail(forKey: photoKey) ?? diskImage
            }

            // 4. Fallback: Firebase Storage
            do {
                if let remoteImage = try await self.photoService.fetchImageForPhoto(photo) {
                    self.cacheService.setThumbnail(remoteImage, forKey: photoKey)
                    self.cacheService.setImage(remoteImage, forKey: photoKey)
                    return self.cacheService.thumbnail(forKey: photoKey) ?? remoteImage
                }
            } catch {
                Self.logger.error("Firebase fallback failed for photo \(photoId): \(error.localizedDescription)")
            }

            return nil
        }

        inFlightLoads[photoId] = task
        let result = await task.value
        inFlightLoads.removeValue(forKey: photoId)
        return result
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

    private func startRealtimeSync() {
        guard !listenerActive else { return }
        listenerActive = true

        photoService.startListening { [weak self] changes in
            guard let self else { return }
            self.applyChanges(changes)
        }
    }

    private func applyChanges(_ changes: [PhotoChange]) {
        for change in changes {
            switch change {
            case .added(let photo):
                if !photos.contains(where: { $0.id == photo.id }) {
                    photos.insert(photo, at: 0)
                }
            case .modified(let photo):
                if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                    photos[index] = photo
                }
            case .removed(let docID):
                photos.removeAll { $0.id.uuidString == docID }
            }
        }
        // Persist updated metadata
        try? storageService.savePhotosMetadata(photos)
    }

    private func handleError(_ error: Error) {
        if let firebaseError = error as? FirebasePhotoError {
            switch firebaseError {
            case .imageCompressionFailed:
                errorMessage = "Failed to compress image for upload."
            case .notAuthenticated:
                errorMessage = "Unable to connect to the photo service. Please try again."
            case .serviceUnavailable:
                errorMessage = "Photo service is temporarily unavailable. Please try again later."
            case .uploadFailed:
                errorMessage = "Failed to upload photo. Please check your connection."
            case .downloadFailed:
                errorMessage = "Failed to download photo. Please check your connection."
            }
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}
