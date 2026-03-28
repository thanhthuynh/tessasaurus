//
//  ConstellationCanvasView.swift
//  Tessasaurus
//

import SwiftUI

struct ConstellationCanvasView: View {
    let photos: [Photo]
    let onPhotoTap: (Photo) -> Void
    let imageLoader: (Photo) async -> UIImage?

    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var fanOutProgress: CGFloat = 0
    @State private var hasFannedOut = false

    // Cached layout
    @State private var cachedPlacements: [PlacedBubble] = []
    @State private var cachedBounds: CGRect = .zero
    @State private var cachedEdges: [ConstellationEdge] = []

    // Drag tracking
    @State private var dragStartOffset: CGPoint? = nil

    @AppStorage("hasCompletedOnboarding") private var onboardingCompleted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let baseBubbleSize: CGFloat = 100
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private let centerMagnification: CGFloat = 1.15
    private let magnificationRadius: CGFloat = 300
    private let haptics = HapticService.shared

    /// Identity hash for detecting meaningful photo changes (not just count)
    private var photosIdentity: Int {
        var hasher = Hasher()
        for photo in photos {
            hasher.combine(photo.id)
            hasher.combine(photo.bubbleSize)
        }
        return hasher.finalize()
    }

    var body: some View {
        GeometryReader { geometry in
            let viewCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                StarfieldBackground(canvasOffset: canvasOffset)

                ConstellationLinesView(
                    edges: cachedEdges,
                    placements: cachedPlacements,
                    canvasOffset: canvasOffset,
                    canvasScale: canvasScale,
                    fanOutProgress: fanOutProgress,
                    viewportSize: geometry.size
                )
                .drawingGroup()

                ForEach(cachedPlacements) { placement in
                    if let photo = photos.first(where: { $0.id == placement.photoID }) {
                        let screenPos = screenPosition(for: placement.position, center: viewCenter)

                        // Visibility culling
                        if isVisible(screenPos: screenPos, viewportSize: geometry.size) {
                            let magnification = magnificationScale(
                                screenPos: screenPos,
                                containerCenter: viewCenter
                            )

                            // Fan-out animation: interpolate from center to final position
                            let animatedPos = animatedPosition(
                                for: placement,
                                center: viewCenter
                            )

                            let animatedScale = bubbleFanScale(for: placement)
                            let animatedOpacity = bubbleFanOpacity(for: placement)

                            PhotoBubble(
                                photo: photo,
                                baseSize: baseBubbleSize,
                                imageLoader: imageLoader,
                                magnificationScale: magnification,
                                distanceFromCenter: distanceFromViewportCenter(screenPos: screenPos, center: viewCenter),
                                onTap: { onPhotoTap(photo) }
                            )
                            .scaleEffect(animatedScale)
                            .opacity(animatedOpacity)
                            .position(animatedPos)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Photo constellation with \(photos.count) photos")
            .accessibilityAction(.magicTap) {
                withAnimation(TessaAnimations.standard) {
                    canvasOffset = .zero
                    canvasScale = 1.0
                    lastScale = 1.0
                }
            }
            .gesture(dragGesture(viewportSize: geometry.size))
            .simultaneousGesture(magnifyGesture(anchor: viewCenter))
            .onAppear {
                recomputeLayout()
                if onboardingCompleted && !hasFannedOut && !photos.isEmpty {
                    performFanOut()
                }
            }
            .onChange(of: photosIdentity) { _, _ in
                recomputeLayout()
                if onboardingCompleted && !hasFannedOut && !photos.isEmpty {
                    performFanOut()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingWillDismiss)) { _ in
                guard !hasFannedOut else { return }
                // Delay 0.5s so fan-out starts ~33% into the 1.5s dissolve
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if !hasFannedOut {
                        performFanOut()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .clipped()
    }

    // MARK: - Layout Cache

    private func recomputeLayout() {
        cachedPlacements = ConstellationLayout.calculatePositions(
            photos: photos,
            baseBubbleSize: baseBubbleSize,
            minSeparation: baseBubbleSize * 1.0 * 1.15 * 1.35
        )
        cachedBounds = computeContentBounds(placements: cachedPlacements)
        cachedEdges = ConstellationEdge.computeEdges(
            placements: cachedPlacements,
            maxNeighborDistance: baseBubbleSize * 4.0
        )
    }

    // MARK: - Fan-Out Animation

    private func performFanOut() {
        if reduceMotion {
            fanOutProgress = 1.0
        } else {
            withAnimation(TessaAnimations.fanOut) {
                fanOutProgress = 1.0
            }
        }
        hasFannedOut = true
    }

    private func animatedPosition(for placement: PlacedBubble, center: CGPoint) -> CGPoint {
        let staggerDelay = CGFloat(placement.ringIndex) * 0.08
        let adjustedProgress = max(0, min(1, (fanOutProgress - staggerDelay) / max(0.01, 1.0 - staggerDelay)))
        let eased = easeOut(adjustedProgress)

        let finalX = placement.position.x * canvasScale + canvasOffset.x + center.x
        let finalY = placement.position.y * canvasScale + canvasOffset.y + center.y

        return CGPoint(
            x: lerp(center.x, finalX, eased),
            y: lerp(center.y, finalY, eased)
        )
    }

    private func bubbleFanScale(for placement: PlacedBubble) -> CGFloat {
        let staggerDelay = CGFloat(placement.ringIndex) * 0.08
        let adjustedProgress = max(0, min(1, (fanOutProgress - staggerDelay) / max(0.01, 1.0 - staggerDelay)))
        return lerp(0.3, 1.0, easeOut(adjustedProgress))
    }

    private func bubbleFanOpacity(for placement: PlacedBubble) -> CGFloat {
        let staggerDelay = CGFloat(placement.ringIndex) * 0.08
        let adjustedProgress = max(0, min(1, (fanOutProgress - staggerDelay) / max(0.01, 1.0 - staggerDelay)))
        return Double(lerp(0, 1, easeOut(adjustedProgress)))
    }

    // MARK: - Gestures

    private func dragGesture(viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let startOffset = dragStartOffset ?? canvasOffset
                if dragStartOffset == nil {
                    dragStartOffset = canvasOffset
                }

                let newOffset = CGPoint(
                    x: startOffset.x + value.translation.width,
                    y: startOffset.y + value.translation.height
                )

                let bounds = scaledBounds()
                canvasOffset = applyRubberBand(offset: newOffset, bounds: bounds)
            }
            .onEnded { value in
                dragStartOffset = nil
                let bounds = scaledBounds()

                // Spring back if beyond bounds
                let clamped = clampToBounds(offset: canvasOffset, bounds: bounds)
                if clamped != canvasOffset {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        canvasOffset = clamped
                    }
                    haptics.panBounce()
                    return
                }

                // Use system-provided predicted end translation for momentum
                let remainingTranslation = CGPoint(
                    x: value.predictedEndTranslation.width - value.translation.width,
                    y: value.predictedEndTranslation.height - value.translation.height
                )

                guard abs(remainingTranslation.x) > 20 || abs(remainingTranslation.y) > 20 else { return }

                let targetOffset = CGPoint(
                    x: canvasOffset.x + remainingTranslation.x,
                    y: canvasOffset.y + remainingTranslation.y
                )
                let clampedTarget = clampToBounds(offset: targetOffset, bounds: bounds)

                withAnimation(.interpolatingSpring(stiffness: 50, damping: 15)) {
                    canvasOffset = clampedTarget
                }

                if clampedTarget != targetOffset {
                    haptics.panBounce()
                }
            }
    }

    private func magnifyGesture(anchor: CGPoint) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                let clampedScale = min(max(newScale, minScale), maxScale)

                // Adjust offset to zoom toward pinch center
                let pinchCenter = value.startLocation
                let deltaScale = clampedScale / canvasScale
                canvasOffset = CGPoint(
                    x: pinchCenter.x - (pinchCenter.x - canvasOffset.x) * deltaScale,
                    y: pinchCenter.y - (pinchCenter.y - canvasOffset.y) * deltaScale
                )

                canvasScale = clampedScale
            }
            .onEnded { value in
                let newScale = lastScale * value.magnification
                let clampedScale = min(max(newScale, minScale), maxScale)

                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    canvasScale = clampedScale
                }
                lastScale = clampedScale

                // Haptic at zoom limits
                if newScale < minScale || newScale > maxScale {
                    haptics.zoomSnap()
                }
            }
    }

    // MARK: - Position Helpers

    private func screenPosition(for position: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: position.x * canvasScale + canvasOffset.x + center.x,
            y: position.y * canvasScale + canvasOffset.y + center.y
        )
    }

    private func isVisible(screenPos: CGPoint, viewportSize: CGSize, margin: CGFloat = 200) -> Bool {
        screenPos.x > -margin && screenPos.x < viewportSize.width + margin &&
        screenPos.y > -margin && screenPos.y < viewportSize.height + margin
    }

    private func magnificationScale(screenPos: CGPoint, containerCenter: CGPoint) -> CGFloat {
        let dx = screenPos.x - containerCenter.x
        let dy = screenPos.y - containerCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        let normalizedDistance = min(distance / magnificationRadius, 1.0)
        let easeOutValue = 1.0 - pow(normalizedDistance, 2)
        return 1.0 + (centerMagnification - 1.0) * easeOutValue
    }

    private func distanceFromViewportCenter(screenPos: CGPoint, center: CGPoint) -> CGFloat {
        let dx = screenPos.x - center.x
        let dy = screenPos.y - center.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Bounds & Rubber Band

    private func computeContentBounds(placements: [PlacedBubble]) -> CGRect {
        guard !placements.isEmpty else { return .zero }
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for p in placements {
            minX = min(minX, p.position.x)
            maxX = max(maxX, p.position.x)
            minY = min(minY, p.position.y)
            maxY = max(maxY, p.position.y)
        }
        let padding: CGFloat = baseBubbleSize * 2
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }

    private func scaledBounds() -> CGRect {
        CGRect(
            x: cachedBounds.origin.x * canvasScale,
            y: cachedBounds.origin.y * canvasScale,
            width: cachedBounds.width * canvasScale,
            height: cachedBounds.height * canvasScale
        )
    }

    private func clampToBounds(offset: CGPoint, bounds: CGRect) -> CGPoint {
        let maxOffsetX = max(0, bounds.width / 2)
        let maxOffsetY = max(0, bounds.height / 2)
        return CGPoint(
            x: max(-maxOffsetX, min(maxOffsetX, offset.x)),
            y: max(-maxOffsetY, min(maxOffsetY, offset.y))
        )
    }

    private func applyRubberBand(offset: CGPoint, bounds: CGRect) -> CGPoint {
        let maxOffsetX = max(0, bounds.width / 2)
        let maxOffsetY = max(0, bounds.height / 2)

        func rubberBand(_ value: CGFloat, _ limit: CGFloat) -> CGFloat {
            if abs(value) <= limit { return value }
            let overshoot = abs(value) - limit
            let sign: CGFloat = value > 0 ? 1 : -1
            return sign * (limit + overshoot * 0.3)
        }

        return CGPoint(
            x: rubberBand(offset.x, maxOffsetX),
            y: rubberBand(offset.y, maxOffsetY)
        )
    }

    // MARK: - Math Helpers

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func easeOut(_ t: CGFloat) -> CGFloat {
        1 - pow(1 - t, 3)
    }
}

#Preview {
    ConstellationCanvasView(
        photos: Photo.samples,
        onPhotoTap: { _ in },
        imageLoader: { _ in nil }
    )
}
