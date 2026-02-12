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
        lhs.id == rhs.id
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
