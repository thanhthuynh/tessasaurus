//
//  PhotoWallViewModel.swift
//  Tessasaurus
//

import SwiftUI
import CloudKit
import Observation

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
    private let cloudService = CloudKitPhotoService.shared
    private let storageService = PhotoStorageService.shared
    private let cacheService = ImageCacheService.shared

    // Key for storing uploader mode preference
    private let uploaderModeKey = "isUploaderMode"

    private var needsRefreshAfterUpload = false
    private var inFlightLoads: [UUID: Task<UIImage?, Never>] = [:]

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
            // Check iCloud account status
            let status = try await cloudService.checkAccountStatus()
            guard status == .available else {
                if status == .noAccount {
                    errorMessage = "Sign in to iCloud in Settings to sync photos"
                    showError = true
                }
                isLoading = false
                return
            }

            // Fetch from CloudKit
            let cloudPhotos = try await cloudService.fetchAllPhotos()

            // Update local cache
            try? storageService.savePhotosMetadata(cloudPhotos)

            photos = cloudPhotos

            // Migrate bubble sizes for existing photos (one-time)
            await migrateBubbleSizesIfNeeded()

            // Subscribe to changes if not already (non-throwing, logs errors internally)
            await cloudService.subscribeToChanges()

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
                let photo = try await cloudService.uploadPhoto(
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
        try? storageService.savePhotosMetadata(photos)

        isUploading = false
        uploadProgress = 0

        // Refresh if a load was deferred during upload
        if needsRefreshAfterUpload {
            needsRefreshAfterUpload = false
            await refresh()
        }

        return UploadResult(successCount: successCount, failureCount: failureCount)
    }

    // MARK: - TEMPORARY: Delete All Photos (remove after use)
    var isDeletingAll = false
    var deleteAllProgress: String?

    func deleteAllPhotos() async {
        guard !isDeletingAll else { return }
        isDeletingAll = true
        deleteAllProgress = "Fetching photos from CloudKit..."

        do {
            // Fetch all record IDs from CloudKit
            let allPhotos = try await cloudService.fetchAllPhotos()
            let total = allPhotos.count

            if total == 0 {
                deleteAllProgress = "No photos found."
                isDeletingAll = false
                return
            }

            deleteAllProgress = "Deleting \(total) photos..."

            for (index, photo) in allPhotos.enumerated() {
                try await cloudService.deletePhoto(photo)
                deleteAllProgress = "Deleted \(index + 1)/\(total)..."
            }

            // Clear local state
            photos.removeAll()
            cacheService.clearCache()
            try? storageService.savePhotosMetadata([])

            deleteAllProgress = "Done! All \(total) photos deleted."
        } catch {
            deleteAllProgress = "Error: \(error.localizedDescription)"
            handleError(error)
        }

        isDeletingAll = false
    }
    // MARK: - END TEMPORARY

    func deletePhoto(_ photo: Photo) async {
        do {
            try await cloudService.deletePhoto(photo)

            photos.removeAll { $0.id == photo.id }

            // Remove from cache
            cacheService.removeImage(forKey: photo.id.uuidString)
            cacheService.removeImage(forKey: "thumb_\(photo.id.uuidString)")

            // Save updated metadata
            try? storageService.savePhotosMetadata(photos)

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
            try await cloudService.updatePhotoBubbleSize(photo, newSize: newSize)
            try? storageService.savePhotosMetadata(photos)
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
            try await cloudService.updatePhotoCaption(photo, newCaption: newCaption)
            try? storageService.savePhotosMetadata(photos)
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
                return self.cacheService.thumbnail(forKey: photoKey)!
            }

            // 4. Fallback: CloudKit
            do {
                if let cloudImage = try await self.cloudService.fetchImageForPhoto(photo) {
                    self.cacheService.setThumbnail(cloudImage, forKey: photoKey)
                    self.cacheService.setImage(cloudImage, forKey: photoKey)
                    return self.cacheService.thumbnail(forKey: photoKey)!
                }
            } catch {
                print("[PhotoWall] CloudKit fallback failed for photo \(photoId): \(error.localizedDescription)")
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

    private func migrateBubbleSizesIfNeeded() async {
        let key = "hasRunBubbleSizeMigration"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        for i in photos.indices {
            photos[i].bubbleSize = BubbleSize.autoAssign(
                photoCount: i,
                aspectRatio: photos[i].aspectRatio
            )
            try? await cloudService.updatePhotoBubbleSize(photos[i], newSize: photos[i].bubbleSize)
        }
        try? storageService.savePhotosMetadata(photos)
        UserDefaults.standard.set(true, forKey: key)
    }

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
}
