//
//  FirebasePhotoService.swift
//  Tessasaurus
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import os

enum PhotoChange: Sendable {
    case added(Photo)
    case modified(Photo)
    case removed(String) // document ID
}

enum FirebasePhotoError: Error, LocalizedError, Sendable {
    case imageCompressionFailed
    case notAuthenticated
    case uploadFailed(message: String)
    case downloadFailed(message: String)
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image for upload"
        case .notAuthenticated:
            return "Unable to connect to the photo service"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .serviceUnavailable:
            return "Photo service is temporarily unavailable"
        }
    }
}

final class FirebasePhotoService: @unchecked Sendable {
    // @unchecked Sendable justification: This is a singleton — `listener` is only mutated
    // from `startListening()` and `stopListening()`, both called on @MainActor from the ViewModel.
    // The Firebase SDK's `ListenerRegistration.remove()` is thread-safe.
    static let shared = FirebasePhotoService()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tessasaurus", category: "Firebase")

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let collectionName = "photos"
    private let storagePath = "photos"
    private var listener: ListenerRegistration?

    private init() {}

    // MARK: - Authentication

    func ensureAuthenticated() async throws {
        if Auth.auth().currentUser != nil { return }

        do {
            try await Auth.auth().signInAnonymously()
        } catch {
            Self.logger.error("Anonymous auth failed: \(error.localizedDescription)")
            throw FirebasePhotoError.notAuthenticated
        }
    }

    // MARK: - Upload

    func uploadPhoto(image: UIImage, caption: String?, bubbleSize: BubbleSize) async throws -> Photo {
        let photoID = UUID()
        let fileName = "\(photoID.uuidString).jpg"

        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw FirebasePhotoError.imageCompressionFailed
        }

        let aspectRatio = image.size.width / image.size.height
        let storageRef = storage.reference().child("\(storagePath)/\(fileName)")

        // Upload image to Firebase Storage
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        } catch {
            throw FirebasePhotoError.uploadFailed(message: error.localizedDescription)
        }

        // Write metadata to Firestore
        let docRef = db.collection(collectionName).document(photoID.uuidString)
        let createdAt = Date()
        let documentData: [String: Any] = [
            "id": photoID.uuidString,
            "caption": caption as Any,
            "createdAt": Timestamp(date: createdAt),
            "aspectRatio": Double(aspectRatio),
            "bubbleSize": bubbleSize.rawValue,
            "storagePath": "\(storagePath)/\(fileName)"
        ]

        do {
            try await docRef.setData(documentData)
        } catch {
            // Clean up Storage on Firestore failure
            try? await storageRef.delete()
            throw FirebasePhotoError.uploadFailed(message: error.localizedDescription)
        }

        // Save locally
        try PhotoStorageService.shared.saveImageData(imageData, fileName: fileName)

        return Photo(
            id: photoID,
            localFileName: fileName,
            cloudRecordID: photoID.uuidString,
            caption: caption,
            createdAt: createdAt,
            aspectRatio: aspectRatio,
            bubbleSize: bubbleSize
        )
    }

    // MARK: - Fetch

    func fetchAllPhotos() async throws -> [Photo] {
        let snapshot = try await db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        var photos: [Photo] = []
        for document in snapshot.documents {
            if let photo = photoFromDocument(document) {
                photos.append(photo)
            }
        }
        return photos
    }

    // MARK: - Fetch Single Image

    func fetchImageForPhoto(_ photo: Photo) async throws -> UIImage? {
        let fileName = photo.localFileName ?? "\(photo.id.uuidString).jpg"
        let storagePath = "\(self.storagePath)/\(fileName)"
        let storageRef = storage.reference().child(storagePath)

        do {
            // Max 10MB download
            let data = try await storageRef.data(maxSize: 10 * 1024 * 1024)
            guard let image = UIImage(data: data) else { return nil }
            try PhotoStorageService.shared.saveImage(image, fileName: fileName)
            return image
        } catch {
            Self.logger.error("Failed to download image for photo \(photo.id): \(error.localizedDescription)")
            throw FirebasePhotoError.downloadFailed(message: error.localizedDescription)
        }
    }

    // MARK: - Delete

    func deletePhoto(_ photo: Photo) async throws {
        let docID = photo.cloudRecordID ?? photo.id.uuidString

        // Delete Firestore document
        try await db.collection(collectionName).document(docID).delete()

        // Delete from Storage
        let fileName = photo.localFileName ?? "\(photo.id.uuidString).jpg"
        let storageRef = storage.reference().child("\(storagePath)/\(fileName)")
        do {
            try await storageRef.delete()
        } catch {
            // Log but don't fail — the Firestore doc is already deleted
            Self.logger.warning("Storage delete failed for \(fileName): \(error.localizedDescription)")
        }

        // Delete local file
        if let localFileName = photo.localFileName {
            try? PhotoStorageService.shared.deleteImage(fileName: localFileName)
        }
    }

    // MARK: - Update

    func updatePhotoCaption(_ photo: Photo, newCaption: String?) async throws {
        let docID = photo.cloudRecordID ?? photo.id.uuidString
        try await db.collection(collectionName).document(docID).updateData([
            "caption": newCaption as Any
        ])
    }

    func updatePhotoBubbleSize(_ photo: Photo, newSize: BubbleSize) async throws {
        let docID = photo.cloudRecordID ?? photo.id.uuidString
        try await db.collection(collectionName).document(docID).updateData([
            "bubbleSize": newSize.rawValue
        ])
    }

    // MARK: - Real-Time Listener

    func startListening(onChange: @escaping @MainActor @Sendable ([PhotoChange]) -> Void) {
        stopListening()

        listener = db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Self.logger.error("Snapshot listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else { return }

                var changes: [PhotoChange] = []
                for diff in snapshot.documentChanges {
                    switch diff.type {
                    case .added:
                        if let photo = self.photoFromDocument(diff.document) {
                            changes.append(.added(photo))
                        }
                    case .modified:
                        if let photo = self.photoFromDocument(diff.document) {
                            changes.append(.modified(photo))
                        }
                    case .removed:
                        changes.append(.removed(diff.document.documentID))
                    }
                }

                if !changes.isEmpty {
                    Task { @MainActor in
                        onChange(changes)
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Private Helpers

    private func photoFromDocument(_ document: QueryDocumentSnapshot) -> Photo? {
        let data = document.data()

        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestamp = data["createdAt"] as? Timestamp,
              let aspectRatio = data["aspectRatio"] as? Double,
              aspectRatio > 0 && aspectRatio < 100,
              let bubbleSizeRaw = data["bubbleSize"] as? String,
              let bubbleSize = BubbleSize(rawValue: bubbleSizeRaw) else {
            Self.logger.warning("Incomplete or invalid metadata for document \(document.documentID)")
            return nil
        }

        let caption = data["caption"] as? String
        let fileName = "\(id.uuidString).jpg"

        return Photo(
            id: id,
            localFileName: fileName,
            cloudRecordID: document.documentID,
            caption: caption,
            createdAt: timestamp.dateValue(),
            aspectRatio: aspectRatio,
            bubbleSize: bubbleSize
        )
    }
}
