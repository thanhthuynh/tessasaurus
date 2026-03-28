//
//  ConstellationLayout.swift
//  Tessasaurus
//

import CoreGraphics
import Foundation

struct PlacedBubble: Identifiable {
    let photoID: UUID
    let index: Int
    var position: CGPoint
    let ringIndex: Int
    let angleInRing: CGFloat
    let bubbleScale: CGFloat

    var id: UUID { photoID }
}

enum ConstellationLayout {
    /// Calculates photo positions in concentric rings using golden ratio spacing.
    /// Photos are sorted by BubbleSize (large -> inner rings, small -> outer rings).
    /// All positions are relative to center (0,0).
    static func calculatePositions(
        photos: [Photo],
        baseBubbleSize: CGFloat = 100,
        minSeparation: CGFloat = 155
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

        let effectiveSpacing = baseBubbleSize * 2.2

        var placements: [PlacedBubble] = []
        var placementIndex = 0

        // Ring 0: center photo
        if placementIndex < sortedIndices.count {
            let originalIndex = sortedIndices[placementIndex]
            placements.append(PlacedBubble(
                photoID: photos[originalIndex].id,
                index: originalIndex,
                position: .zero,
                ringIndex: 0,
                angleInRing: 0,
                bubbleScale: photos[originalIndex].bubbleSize.scale
            ))
            placementIndex += 1
        }

        // Subsequent rings
        var ring = 1
        while placementIndex < sortedIndices.count {
            let photosInRing = 6 * ring
            let ringRadius = effectiveSpacing * CGFloat(ring) + effectiveSpacing * 0.5 * log(CGFloat(ring + 1))

            for slot in 0..<photosInRing {
                guard placementIndex < sortedIndices.count else { break }

                let originalIndex = sortedIndices[placementIndex]
                let baseAngle = (CGFloat.pi * 2.0 * CGFloat(slot)) / CGFloat(photosInRing)

                // Deterministic jitter seeded by original index (overflow-safe)
                let seed = Double(originalIndex &* 73856093 ^ originalIndex &* 19349663)
                let jitterAngle = CGFloat(sin(seed) * 0.15)
                let jitterRadius = CGFloat(cos(seed * 1.3) * 12)

                let angle = baseAngle + jitterAngle
                let radius = ringRadius + jitterRadius

                let x = cos(angle) * radius
                let y = sin(angle) * radius

                placements.append(PlacedBubble(
                    photoID: photos[originalIndex].id,
                    index: originalIndex,
                    position: CGPoint(x: x, y: y),
                    ringIndex: ring,
                    angleInRing: baseAngle,
                    bubbleScale: photos[originalIndex].bubbleSize.scale
                ))
                placementIndex += 1
            }
            ring += 1
        }

        // Resolve any remaining collisions
        resolveCollisions(&placements, baseBubbleSize: baseBubbleSize, minSeparation: minSeparation)

        // Re-sort by original index so placements[i] corresponds to photos[i]
        return placements.sorted { $0.index < $1.index }
    }

    // MARK: - Collision Resolution

    private static func resolveCollisions(
        _ placements: inout [PlacedBubble],
        baseBubbleSize: CGFloat,
        minSeparation: CGFloat,
        maxIterations: Int = 5
    ) {
        guard placements.count > 1 else { return }
        let maxPushPerIteration = baseBubbleSize * 0.5

        for _ in 0..<maxIterations {
            var hasOverlap = false
            for i in 0..<placements.count {
                for j in (i+1)..<placements.count {
                    let ri = baseBubbleSize * placements[i].bubbleScale * 1.25 / 2
                    let rj = baseBubbleSize * placements[j].bubbleScale * 1.25 / 2
                    let minDist = ri + rj + 8

                    let dx = placements[j].position.x - placements[i].position.x
                    let dy = placements[j].position.y - placements[i].position.y
                    let dist = sqrt(dx * dx + dy * dy)

                    if dist < minDist && dist > 0.001 {
                        hasOverlap = true
                        let overlap = min((minDist - dist) / 2, maxPushPerIteration)
                        let nx = dx / dist
                        let ny = dy / dist

                        let wi = CGFloat(placements[i].ringIndex + 1)
                        let wj = CGFloat(placements[j].ringIndex + 1)
                        let total = wi + wj

                        placements[i].position.x -= nx * overlap * (wj / total)
                        placements[i].position.y -= ny * overlap * (wj / total)
                        placements[j].position.x += nx * overlap * (wi / total)
                        placements[j].position.y += ny * overlap * (wi / total)
                    } else if dist <= 0.001 {
                        placements[j].position.x += baseBubbleSize * 0.5
                        hasOverlap = true
                    }
                }
            }
            if !hasOverlap { break }
        }
    }
}
