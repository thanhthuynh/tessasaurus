//
//  CloudKitPhotoService.swift
//  Tessasaurus
//

import CloudKit
import UIKit

final class CloudKitPhotoService {
    static let shared = CloudKitPhotoService()

    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "Photo"

    private init() {
        container = CKContainer(identifier: "iCloud.personal.thanhhuynh.Tessasaurus")
        database = container.publicCloudDatabase
    }

    // MARK: - Upload

    func uploadPhoto(image: UIImage, caption: String?, bubbleSize: BubbleSize) async throws -> Photo {
        let photoID = UUID()
        let fileName = "\(photoID.uuidString).jpg"

        // Create temporary file for CKAsset
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw CloudKitError.imageCompressionFailed
        }
        try imageData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Calculate aspect ratio
        let aspectRatio = image.size.width / image.size.height

        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: photoID.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["id"] = photoID.uuidString
        record["image"] = CKAsset(fileURL: tempURL)
        record["caption"] = caption
        record["createdAt"] = Date()
        record["aspectRatio"] = Double(aspectRatio)
        record["bubbleSize"] = bubbleSize.rawValue

        // Save to CloudKit
        let savedRecord = try await database.save(record)

        // Save locally
        try PhotoStorageService.shared.saveImage(image, fileName: fileName)

        return Photo(
            id: photoID,
            localFileName: fileName,
            cloudRecordID: savedRecord.recordID.recordName,
            caption: caption,
            createdAt: Date(),
            aspectRatio: aspectRatio,
            bubbleSize: bubbleSize
        )
    }

    // MARK: - Fetch

    func fetchAllPhotos() async throws -> [Photo] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (matchResults, _) = try await database.records(matching: query)

        var photos: [Photo] = []

        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let photo = try await photoFromRecord(record) {
                    photos.append(photo)
                }
            case .failure:
                continue
            }
        }

        return photos
    }

    private func photoFromRecord(_ record: CKRecord) async throws -> Photo? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let createdAt = record["createdAt"] as? Date,
              let aspectRatio = record["aspectRatio"] as? Double,
              let bubbleSizeRaw = record["bubbleSize"] as? String,
              let bubbleSize = BubbleSize(rawValue: bubbleSizeRaw) else {
            print("[CloudKit] Incomplete metadata for record \(record.recordID.recordName)")
            return nil
        }

        let caption = record["caption"] as? String
        let fileName = "\(id.uuidString).jpg"

        // Download image if not cached locally
        if !PhotoStorageService.shared.imageExists(fileName: fileName) {
            if let asset = record["image"] as? CKAsset,
               let fileURL = asset.fileURL {
                if let imageData = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: imageData) {
                    try? PhotoStorageService.shared.saveImage(image, fileName: fileName)
                } else {
                    print("[CloudKit] Failed to read image data for photo \(id)")
                }
            } else {
                print("[CloudKit] No asset/fileURL for photo \(id)")
            }
        }

        return Photo(
            id: id,
            localFileName: fileName,
            cloudRecordID: record.recordID.recordName,
            caption: caption,
            createdAt: createdAt,
            aspectRatio: aspectRatio,
            bubbleSize: bubbleSize
        )
    }

    // MARK: - Fetch Single Image

    func fetchImageForPhoto(_ photo: Photo) async throws -> UIImage? {
        guard let recordName = photo.cloudRecordID else { return nil }
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await database.record(for: recordID)
        guard let asset = record["image"] as? CKAsset,
              let fileURL = asset.fileURL else { return nil }
        let imageData = try Data(contentsOf: fileURL)
        guard let image = UIImage(data: imageData) else { return nil }
        let fileName = photo.localFileName ?? "\(photo.id.uuidString).jpg"
        try PhotoStorageService.shared.saveImage(image, fileName: fileName)
        return image
    }

    // MARK: - Delete

    func deletePhoto(_ photo: Photo) async throws {
        guard let recordID = photo.cloudRecordID else { return }

        let ckRecordID = CKRecord.ID(recordName: recordID)
        try await database.deleteRecord(withID: ckRecordID)

        if let fileName = photo.localFileName {
            try? PhotoStorageService.shared.deleteImage(fileName: fileName)
        }
    }

    // MARK: - Update

    func updatePhotoCaption(_ photo: Photo, newCaption: String?) async throws {
        guard let recordName = photo.cloudRecordID else { return }
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: "Photo", recordID: recordID)
        record["caption"] = newCaption

        let operation = CKModifyRecordsOperation(
            recordsToSave: [record],
            recordIDsToDelete: nil
        )
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            self.database.add(operation)
        }
    }

    // MARK: - Subscriptions

    func subscribeToChanges() async {
        let subscriptionID = "photo-changes"

        // Check if subscription already exists
        do {
            _ = try await database.subscription(for: subscriptionID)
            return // Subscription already exists
        } catch {
            // Subscription doesn't exist, create it
        }

        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "New photos added to your wall!"
        notificationInfo.shouldBadge = true
        notificationInfo.soundName = "default"
        subscription.notificationInfo = notificationInfo

        do {
            try await database.save(subscription)
        } catch {
            // Log the error but don't propagate - subscription setup is non-critical
            // This commonly fails with "Field 'recordName' is not marked queryable"
            // when CloudKit Dashboard indexes are not configured
            print("CloudKit subscription setup failed (non-critical): \(error.localizedDescription)")
        }
    }

    // MARK: - Account Status

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}

enum CloudKitError: Error, LocalizedError {
    case imageCompressionFailed
    case noAccount
    case restricted
    case temporarilyUnavailable
    case unknown

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image for upload"
        case .noAccount:
            return "Please sign in to iCloud to sync photos"
        case .restricted:
            return "iCloud access is restricted"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
