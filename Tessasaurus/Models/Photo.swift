//
//  Photo.swift
//  Tessasaurus
//

import Foundation

enum BubbleSize: String, Codable, CaseIterable {
    case small
    case medium
    case large

    var scale: CGFloat {
        switch self {
        case .small: return 0.6
        case .medium: return 0.85
        case .large: return 1.0
        }
    }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    static func autoAssign(photoCount: Int, aspectRatio: CGFloat) -> BubbleSize {
        // First 5 photos are always large (founding memories)
        if photoCount < 5 { return .large }

        // Near-square photos (0.85–1.15 aspect ratio) get a size bump
        let isNearSquare = aspectRatio >= 0.85 && aspectRatio <= 1.15

        // Deterministic distribution using stable modular arithmetic (not hashValue)
        let seed = photoCount &* 2654435761 // Knuth multiplicative hash, overflow-safe
        let bucket = (seed & 0x7FFFFFFF) % 100 // mask sign bit, then mod
        if isNearSquare {
            // Bump: 35% large, 40% medium, 25% small
            if bucket < 35 { return .large }
            else if bucket < 75 { return .medium }
            else { return .small }
        } else {
            // 25% large, 45% medium, 30% small
            if bucket < 25 { return .large }
            else if bucket < 70 { return .medium }
            else { return .small }
        }
    }
}

struct Photo: Identifiable, Codable, Equatable {
    let id: UUID
    var localFileName: String?
    var cloudRecordID: String?
    var assetImageName: String?
    var caption: String?
    var createdAt: Date
    var aspectRatio: CGFloat
    var bubbleSize: BubbleSize

    init(
        id: UUID = UUID(),
        localFileName: String? = nil,
        cloudRecordID: String? = nil,
        assetImageName: String? = nil,
        caption: String? = nil,
        createdAt: Date = Date(),
        aspectRatio: CGFloat = 1.0,
        bubbleSize: BubbleSize = .medium
    ) {
        self.id = id
        self.localFileName = localFileName
        self.cloudRecordID = cloudRecordID
        self.assetImageName = assetImageName
        self.caption = caption
        self.createdAt = createdAt
        self.aspectRatio = aspectRatio
        self.bubbleSize = bubbleSize
    }

    // Migration initializer for legacy Photo format
    init(imageName: String, caption: String? = nil, date: Date? = nil, aspectRatio: CGFloat = 1.0) {
        self.id = UUID()
        self.localFileName = nil
        self.cloudRecordID = nil
        self.assetImageName = imageName
        self.caption = caption
        self.createdAt = date ?? Date()
        self.aspectRatio = aspectRatio
        self.bubbleSize = .medium
    }

    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id &&
        lhs.caption == rhs.caption &&
        lhs.bubbleSize == rhs.bubbleSize &&
        lhs.localFileName == rhs.localFileName &&
        lhs.aspectRatio == rhs.aspectRatio
    }
}

extension UUID {
    /// Stable hash derived from the first 8 UUID bytes — unlike `hashValue`, this is deterministic
    /// across launches. Uses only bytes 0-7 (sufficient for color/layout distribution).
    var stableHash: Int {
        let (a, b, c, d, e, f, g, h, _, _, _, _, _, _, _, _) = uuid
        return (Int(a) &<< 24 | Int(b) &<< 16 | Int(c) &<< 8 | Int(d))
            ^ (Int(e) &<< 24 | Int(f) &<< 16 | Int(g) &<< 8 | Int(h))
    }
}

extension Photo {
    static let samples: [Photo] = [
        Photo(assetImageName: "photo1", caption: "Our first date", createdAt: Date(), aspectRatio: 0.75, bubbleSize: .large),
        Photo(assetImageName: "photo2", caption: "Beach sunset", createdAt: Date(), aspectRatio: 1.5, bubbleSize: .medium),
        Photo(assetImageName: "photo3", caption: "Coffee morning", createdAt: Date(), aspectRatio: 1.0, bubbleSize: .small),
        Photo(assetImageName: "photo4", caption: "City adventures", createdAt: Date(), aspectRatio: 0.8, bubbleSize: .large),
        Photo(assetImageName: "photo5", caption: "Cooking together", createdAt: Date(), aspectRatio: 1.2, bubbleSize: .medium),
        Photo(assetImageName: "photo6", caption: "Movie night", createdAt: Date(), aspectRatio: 0.9, bubbleSize: .small)
    ]
}
