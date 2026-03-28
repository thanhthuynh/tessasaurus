//
//  ModelTests.swift
//  TessasaurusTests
//

import Testing
import Foundation
import CoreGraphics
@testable import Tessasaurus

// MARK: - BubbleSizeTests

struct BubbleSizeTests {
    @Test func scaleForSmall() {
        #expect(BubbleSize.small.scale == 0.6)
    }

    @Test func scaleForMedium() {
        #expect(BubbleSize.medium.scale == 0.85)
    }

    @Test func scaleForLarge() {
        #expect(BubbleSize.large.scale == 1.0)
    }

    @Test(arguments: zip(
        BubbleSize.allCases,
        ["Small", "Medium", "Large"]
    ))
    func displayNameForAllCases(size: BubbleSize, expected: String) {
        #expect(size.displayName == expected)
    }

    @Test(arguments: 0..<5)
    func autoAssignAlwaysLargeUnderFive(count: Int) {
        #expect(BubbleSize.autoAssign(photoCount: count, aspectRatio: 0.5) == .large)
        #expect(BubbleSize.autoAssign(photoCount: count, aspectRatio: 1.0) == .large)
        #expect(BubbleSize.autoAssign(photoCount: count, aspectRatio: 2.0) == .large)
    }

    @Test func autoAssignNearSquareLowerBound() {
        // aspectRatio 0.85 is the lower bound for near-square
        #expect(BubbleSize.autoAssign(photoCount: 6, aspectRatio: 0.85) == .large)
    }

    @Test func autoAssignBelowNearSquareLowerBound() {
        // aspectRatio 0.84 falls into the non-square path
        #expect(BubbleSize.autoAssign(photoCount: 6, aspectRatio: 0.84) == .medium)
    }

    @Test func autoAssignNearSquareUpperBound() {
        #expect(BubbleSize.autoAssign(photoCount: 6, aspectRatio: 1.15) == .large)
    }

    @Test func autoAssignAboveNearSquareUpperBound() {
        #expect(BubbleSize.autoAssign(photoCount: 6, aspectRatio: 1.16) == .medium)
    }

    // Verify all three BubbleSize values are reachable from the non-square path
    @Test func autoAssignReachesLargeNonSquare() {
        // photoCount=5, seed=5*2654435761=13272178805, bucket=17 (<25 -> large)
        #expect(BubbleSize.autoAssign(photoCount: 5, aspectRatio: 1.5) == .large)
    }

    @Test func autoAssignReachesMediumNonSquare() {
        // photoCount=6, bucket=30 (25<=30<70 -> medium)
        #expect(BubbleSize.autoAssign(photoCount: 6, aspectRatio: 1.5) == .medium)
    }

    @Test func autoAssignReachesSmallNonSquare() {
        // photoCount=21, bucket=81 (>=70 -> small)
        #expect(BubbleSize.autoAssign(photoCount: 21, aspectRatio: 1.5) == .small)
    }

    // Verify all three BubbleSize values are reachable from the near-square path
    @Test func autoAssignReachesLargeNearSquare() {
        // photoCount=6, bucket=30 (<35 -> large)
        #expect(BubbleSize.autoAssign(photoCount: 6, aspectRatio: 1.0) == .large)
    }

    @Test func autoAssignReachesMediumNearSquare() {
        // photoCount=7, bucket=43 (35<=43<75 -> medium)
        #expect(BubbleSize.autoAssign(photoCount: 7, aspectRatio: 1.0) == .medium)
    }

    @Test func autoAssignReachesSmallNearSquare() {
        // photoCount=21, bucket=81 (>=75 -> small)
        #expect(BubbleSize.autoAssign(photoCount: 21, aspectRatio: 1.0) == .small)
    }
}

// MARK: - UUIDStableHashTests

struct UUIDStableHashTests {
    @Test func deterministicAcrossCalls() {
        let uuid = UUID()
        let hash1 = uuid.stableHash
        let hash2 = uuid.stableHash
        #expect(hash1 == hash2)
    }

    @Test func knownValueRegression() {
        // Bytes: 01 02 03 04 - 05 06 07 08 - ...
        // (0x01020304) ^ (0x05060708) = 0x0404040c = 67372044
        let uuid = UUID(uuidString: "01020304-0506-0708-090A-0B0C0D0E0F10")!
        #expect(uuid.stableHash == 67372044)
    }

    @Test func allZeroUUIDHashesZero() {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        #expect(uuid.stableHash == 0)
    }

    @Test func differentUUIDsProduceDifferentHashes() {
        // First 4 and second 4 bytes must differ to produce non-zero XOR results
        let a = UUID(uuidString: "01020304-0506-0708-0000-000000000000")!
        let b = UUID(uuidString: "11223344-5566-7788-0000-000000000000")!
        let c = UUID(uuidString: "AABBCCDD-1122-3344-0000-000000000000")!
        let hashes = Set([a.stableHash, b.stableHash, c.stableHash])
        #expect(hashes.count == 3)
    }

    @Test func onlyFirstEightBytesContribute() {
        // Same first 8 bytes, different last 8 bytes — should produce identical hash
        let a = UUID(uuidString: "01020304-0506-0708-0000-000000000000")!
        let b = UUID(uuidString: "01020304-0506-0708-FFFF-FFFFFFFFFFFF")!
        #expect(a.stableHash == b.stableHash)
    }
}

// MARK: - PhotoEqualityTests

struct PhotoEqualityTests {
    private func makePhoto(
        id: UUID = UUID(),
        caption: String? = nil,
        bubbleSize: BubbleSize = .medium,
        localFileName: String? = nil,
        aspectRatio: CGFloat = 1.0,
        cloudRecordID: String? = nil,
        assetImageName: String? = nil,
        createdAt: Date = Date()
    ) -> Photo {
        Photo(
            id: id,
            localFileName: localFileName,
            cloudRecordID: cloudRecordID,
            assetImageName: assetImageName,
            caption: caption,
            createdAt: createdAt,
            aspectRatio: aspectRatio,
            bubbleSize: bubbleSize
        )
    }

    @Test func equalWhenAllComparedFieldsMatch() {
        let id = UUID()
        let a = makePhoto(id: id, caption: "hello", bubbleSize: .large, localFileName: "a.jpg", aspectRatio: 1.5)
        let b = makePhoto(id: id, caption: "hello", bubbleSize: .large, localFileName: "a.jpg", aspectRatio: 1.5)
        #expect(a == b)
    }

    @Test func differentCloudRecordIDStillEqual() {
        let id = UUID()
        let a = makePhoto(id: id, cloudRecordID: "rec-1")
        let b = makePhoto(id: id, cloudRecordID: "rec-2")
        #expect(a == b)
    }

    @Test func differentAssetImageNameStillEqual() {
        let id = UUID()
        let a = makePhoto(id: id, assetImageName: "photo1")
        let b = makePhoto(id: id, assetImageName: "photo2")
        #expect(a == b)
    }

    @Test func differentCreatedAtStillEqual() {
        let id = UUID()
        let a = makePhoto(id: id, createdAt: Date(timeIntervalSince1970: 0))
        let b = makePhoto(id: id, createdAt: Date(timeIntervalSince1970: 86400))
        #expect(a == b)
    }

    @Test func notEqualWhenIDDiffers() {
        let a = makePhoto(id: UUID())
        let b = makePhoto(id: UUID())
        #expect(a != b)
    }

    @Test func notEqualWhenCaptionDiffers() {
        let id = UUID()
        let a = makePhoto(id: id, caption: "hello")
        let b = makePhoto(id: id, caption: "world")
        #expect(a != b)
    }

    @Test func notEqualWhenAspectRatioDiffers() {
        let id = UUID()
        let a = makePhoto(id: id, aspectRatio: 1.0)
        let b = makePhoto(id: id, aspectRatio: 1.5)
        #expect(a != b)
    }

    @Test func notEqualWhenBubbleSizeDiffers() {
        let id = UUID()
        let a = makePhoto(id: id, bubbleSize: .small)
        let b = makePhoto(id: id, bubbleSize: .large)
        #expect(a != b)
    }

    @Test func notEqualWhenLocalFileNameDiffers() {
        let id = UUID()
        let a = makePhoto(id: id, localFileName: "a.jpg")
        let b = makePhoto(id: id, localFileName: "b.jpg")
        #expect(a != b)
    }
}

// MARK: - PhotoCodableTests

struct PhotoCodableTests {
    @Test func roundTripWithAllNilOptionals() throws {
        let original = Photo(
            id: UUID(),
            localFileName: nil,
            cloudRecordID: nil,
            assetImageName: nil,
            caption: nil,
            createdAt: Date(timeIntervalSince1970: 1000000),
            aspectRatio: 1.0,
            bubbleSize: .medium
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Photo.self, from: data)
        #expect(decoded == original)
    }

    @Test func roundTripWithAllFieldsPopulated() throws {
        let original = Photo(
            id: UUID(),
            localFileName: "test.jpg",
            cloudRecordID: "record-123",
            assetImageName: "asset1",
            caption: "A beautiful sunset",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            aspectRatio: 1.5,
            bubbleSize: .large
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Photo.self, from: data)
        #expect(decoded == original)
    }

    @Test func roundTripPreservesBubbleSizeRawValue() throws {
        let original = Photo(bubbleSize: .small)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Photo.self, from: data)
        #expect(decoded.bubbleSize == .small)
    }
}
