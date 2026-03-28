//
//  LayoutTests.swift
//  TessasaurusTests
//

import Testing
import Foundation
import CoreGraphics
@testable import Tessasaurus

// MARK: - ConstellationLayoutTests

struct ConstellationLayoutTests {
    private func makePhoto(bubbleSize: BubbleSize = .medium) -> Photo {
        Photo(id: UUID(), bubbleSize: bubbleSize)
    }

    private func makePhotos(count: Int, bubbleSize: BubbleSize = .medium) -> [Photo] {
        (0..<count).map { _ in makePhoto(bubbleSize: bubbleSize) }
    }

    @Test func emptyArrayReturnsEmpty() {
        let result = ConstellationLayout.calculatePositions(photos: [])
        #expect(result.isEmpty)
    }

    @Test func singlePhotoPlacedAtOrigin() {
        let photos = [makePhoto()]
        let result = ConstellationLayout.calculatePositions(photos: photos)
        #expect(result.count == 1)
        #expect(result[0].position.x == 0)
        #expect(result[0].position.y == 0)
    }

    @Test func singlePhotoInRingZero() {
        let photos = [makePhoto()]
        let result = ConstellationLayout.calculatePositions(photos: photos)
        #expect(result[0].ringIndex == 0)
    }

    @Test(arguments: [1, 2, 7, 13])
    func resultCountMatchesInput(count: Int) {
        let photos = makePhotos(count: count)
        let result = ConstellationLayout.calculatePositions(photos: photos)
        #expect(result.count == count)
    }

    @Test func resultSortedByIndex() {
        let photos = makePhotos(count: 6)
        let result = ConstellationLayout.calculatePositions(photos: photos)
        let indices = result.map(\.index)
        #expect(indices == Array(0..<6))
    }

    @Test func deterministicOutput() {
        // Use fixed UUIDs for reproducibility
        let fixedIDs = (0..<5).map { UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", $0))")! }
        let photos = fixedIDs.map { Photo(id: $0, bubbleSize: .medium) }

        let result1 = ConstellationLayout.calculatePositions(photos: photos)
        let result2 = ConstellationLayout.calculatePositions(photos: photos)

        for i in 0..<result1.count {
            #expect(result1[i].position.x == result2[i].position.x)
            #expect(result1[i].position.y == result2[i].position.y)
        }
    }

    @Test func largePhotosInInnerRings() {
        // 1 large + 6 small — the large photo should be placed in ring 0 (center)
        var photos = [makePhoto(bubbleSize: .large)]
        photos += makePhotos(count: 6, bubbleSize: .small)

        let result = ConstellationLayout.calculatePositions(photos: photos)

        // Find the placement for our large photo (index 0)
        let largePlacement = result.first { $0.index == 0 }!
        #expect(largePlacement.ringIndex == 0)

        // All small photos should be in ring 1
        let smallPlacements = result.filter { $0.index > 0 }
        for placement in smallPlacements {
            #expect(placement.ringIndex == 1)
        }
    }
}

// MARK: - ConstellationEdgeTests

struct ConstellationEdgeTests {
    private func makePlacement(index: Int, x: CGFloat, y: CGFloat) -> PlacedBubble {
        PlacedBubble(
            photoID: UUID(),
            index: index,
            position: CGPoint(x: x, y: y),
            ringIndex: 0,
            angleInRing: 0,
            bubbleScale: 1.0
        )
    }

    @Test func emptyPlacementsReturnsEmpty() {
        let edges = ConstellationEdge.computeEdges(placements: [], maxNeighborDistance: 1000)
        #expect(edges.isEmpty)
    }

    @Test func singlePlacementReturnsEmpty() {
        let placements = [makePlacement(index: 0, x: 0, y: 0)]
        let edges = ConstellationEdge.computeEdges(placements: placements, maxNeighborDistance: 1000)
        #expect(edges.isEmpty)
    }

    @Test func edgeCountGrowsSublinearly() {
        // Each placement contributes at most 3 outbound edges
        let placements = (0..<8).map { i in
            makePlacement(index: i, x: CGFloat(i) * 10, y: 0)
        }
        let edges = ConstellationEdge.computeEdges(placements: placements, maxNeighborDistance: 10000)

        // Upper bound: each of 8 placements adds at most 3 edges = 24 before dedup
        #expect(edges.count <= 24)
        // Should have at least some edges for tightly-packed placements
        #expect(edges.count > 0)
    }

    @Test func noDuplicateEdges() {
        let placements = (0..<8).map { i in
            makePlacement(index: i, x: CGFloat(i) * 10, y: 0)
        }
        let edges = ConstellationEdge.computeEdges(placements: placements, maxNeighborDistance: 10000)

        // Check all (min, max) pairs are unique
        var pairs = Set<String>()
        for edge in edges {
            let key = "\(min(edge.fromIndex, edge.toIndex))-\(max(edge.fromIndex, edge.toIndex))"
            #expect(!pairs.contains(key), "Duplicate edge: \(key)")
            pairs.insert(key)
        }
    }

    @Test func edgesOnlyWithinMaxDistance() {
        let a = makePlacement(index: 0, x: 0, y: 0)
        let b = makePlacement(index: 1, x: 100, y: 0)

        // Below threshold — no edges
        let edgesNarrow = ConstellationEdge.computeEdges(placements: [a, b], maxNeighborDistance: 50)
        #expect(edgesNarrow.isEmpty)

        // Above threshold — one edge
        let edgesWide = ConstellationEdge.computeEdges(placements: [a, b], maxNeighborDistance: 200)
        #expect(edgesWide.count == 1)
    }
}
