//
//  ConstellationLinesView.swift
//  Tessasaurus
//

import SwiftUI

struct ConstellationEdge {
    let fromIndex: Int
    let toIndex: Int

    /// Computes edges between nearby placements. Each placement connects to up to 3 nearest neighbors.
    /// Uses Cantor pairing for O(1) dedup instead of string interpolation.
    static func computeEdges(placements: [PlacedBubble], maxNeighborDistance: CGFloat) -> [ConstellationEdge] {
        var drawnPairs = Set<Int>()
        var edges: [ConstellationEdge] = []

        for placement in placements {
            var neighbors: [(index: Int, distance: CGFloat)] = []

            for other in placements where other.index != placement.index {
                let dx = placement.position.x - other.position.x
                let dy = placement.position.y - other.position.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < maxNeighborDistance {
                    neighbors.append((other.index, dist))
                }
            }

            neighbors.sort { $0.distance < $1.distance }

            for neighbor in neighbors.prefix(3) {
                let a = min(placement.index, neighbor.index)
                let b = max(placement.index, neighbor.index)
                // Cantor pairing function
                let pairKey = (a + b) * (a + b + 1) / 2 + b
                guard !drawnPairs.contains(pairKey) else { continue }
                drawnPairs.insert(pairKey)
                edges.append(ConstellationEdge(fromIndex: a, toIndex: b))
            }
        }

        return edges
    }
}

struct ConstellationLinesView: View {
    let edges: [ConstellationEdge]
    let placements: [PlacedBubble]
    let canvasOffset: CGPoint
    let canvasScale: CGFloat
    let fanOutProgress: CGFloat
    let viewportSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard !placements.isEmpty else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let margin: CGFloat = 200

            // Build index lookup for O(1) access
            var indexMap: [Int: Int] = [:]
            for (arrayIndex, placement) in placements.enumerated() {
                indexMap[placement.index] = arrayIndex
            }

            for edge in edges {
                guard let fromArrayIdx = indexMap[edge.fromIndex],
                      let toArrayIdx = indexMap[edge.toIndex] else { continue }

                let fromPos = screenPosition(for: placements[fromArrayIdx].position, center: center)
                let toPos = screenPosition(for: placements[toArrayIdx].position, center: center)

                // Cull if both endpoints are outside viewport
                let fromVisible = fromPos.x > -margin && fromPos.x < viewportSize.width + margin &&
                                  fromPos.y > -margin && fromPos.y < viewportSize.height + margin
                let toVisible = toPos.x > -margin && toPos.x < viewportSize.width + margin &&
                                toPos.y > -margin && toPos.y < viewportSize.height + margin
                guard fromVisible || toVisible else { continue }

                var path = Path()
                path.move(to: fromPos)
                path.addLine(to: toPos)

                context.stroke(
                    path,
                    with: .color(TessaColors.primaryLight.opacity(0.15 * fanOutProgress)),
                    lineWidth: 0.5
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func screenPosition(for position: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: position.x * canvasScale + canvasOffset.x + center.x,
            y: position.y * canvasScale + canvasOffset.y + center.y
        )
    }
}
