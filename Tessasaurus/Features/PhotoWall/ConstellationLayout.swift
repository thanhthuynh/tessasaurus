//
//  ConstellationLayout.swift
//  Tessasaurus
//

import CoreGraphics

struct PlacedBubble: Identifiable {
    let index: Int
    let position: CGPoint
    let ringIndex: Int
    let angleInRing: CGFloat

    var id: Int { index }
}

enum ConstellationLayout {
    /// Calculates photo positions in concentric rings using golden ratio spacing.
    /// Photos are sorted by BubbleSize (large -> inner rings, small -> outer rings).
    /// All positions are relative to center (0,0).
    static func calculatePositions(
        photos: [Photo],
        baseSpacing: CGFloat = 140
    ) -> [PlacedBubble] {
        guard !photos.isEmpty else { return [] }

        // Sort indices by bubble size: large first (inner rings), then medium, then small
        let sortedIndices = photos.indices.sorted { a, b in
            let sizeOrder: (BubbleSize) -> Int = { size in
                switch size {
                case .large: return 0
                case .medium: return 1
                case .small: return 2
                }
            }
            return sizeOrder(photos[a].bubbleSize) < sizeOrder(photos[b].bubbleSize)
        }

        var placements: [PlacedBubble] = []
        var placementIndex = 0

        // Ring 0: center photo
        if placementIndex < sortedIndices.count {
            let originalIndex = sortedIndices[placementIndex]
            placements.append(PlacedBubble(
                index: originalIndex,
                position: .zero,
                ringIndex: 0,
                angleInRing: 0
            ))
            placementIndex += 1
        }

        // Subsequent rings
        var ring = 1
        while placementIndex < sortedIndices.count {
            let photosInRing = 6 * ring
            let ringRadius = baseSpacing * CGFloat(ring) + baseSpacing * 0.5 * log(CGFloat(ring + 1))

            for slot in 0..<photosInRing {
                guard placementIndex < sortedIndices.count else { break }

                let originalIndex = sortedIndices[placementIndex]
                let baseAngle = (CGFloat.pi * 2.0 * CGFloat(slot)) / CGFloat(photosInRing)

                // Deterministic jitter seeded by original index
                let seed = Double(originalIndex * 73856093 ^ originalIndex * 19349663)
                let jitterAngle = CGFloat(sin(seed) * 0.15)
                let jitterRadius = CGFloat(cos(seed * 1.3) * 12)

                let angle = baseAngle + jitterAngle
                let radius = ringRadius + jitterRadius

                let x = cos(angle) * radius
                let y = sin(angle) * radius

                placements.append(PlacedBubble(
                    index: originalIndex,
                    position: CGPoint(x: x, y: y),
                    ringIndex: ring,
                    angleInRing: baseAngle
                ))
                placementIndex += 1
            }
            ring += 1
        }

        // Re-sort by original index so placements[i] corresponds to photos[i]
        return placements.sorted { $0.index < $1.index }
    }
}
