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
    @State private var momentumController: MomentumController?

    // Cached layout
    @State private var cachedPlacements: [PlacedBubble] = []
    @State private var cachedBounds: CGRect = .zero
    @State private var cachedEdges: [ConstellationEdge] = []

    // Drag tracking for velocity
    @State private var dragStartOffset: CGPoint? = nil
    @State private var lastDragPosition: CGPoint = .zero
    @State private var lastDragTime: Date = .now
    @State private var dragVelocity: CGPoint = .zero
    @GestureState private var isDragging = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let baseBubbleSize: CGFloat = 100
    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 3.0
    private let centerMagnification: CGFloat = 1.3
    private let magnificationRadius: CGFloat = 200
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
                StarfieldBackground(canvasOffset: canvasOffset, canvasScale: canvasScale)

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
                    if placement.index < photos.count {
                        let photo = photos[placement.index]
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
                let onboardingDone = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                if onboardingDone && !hasFannedOut && !photos.isEmpty {
                    performFanOut()
                }
            }
            .onDisappear {
                momentumController?.stop()
                momentumController = nil
            }
            .onChange(of: photosIdentity) { _, _ in
                recomputeLayout()
                let onboardingDone = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                if onboardingDone && !hasFannedOut && !photos.isEmpty {
                    performFanOut()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingWillDismiss)) { _ in
                guard !hasFannedOut else { return }
                // Delay 0.5s so fan-out starts ~33% into the 1.5s dissolve
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            baseSpacing: baseBubbleSize * 1.4
        )
        cachedBounds = computeContentBounds(placements: cachedPlacements)
        cachedEdges = ConstellationEdge.computeEdges(
            placements: cachedPlacements,
            maxNeighborDistance: baseBubbleSize * 3.0
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
        DragGesture()
            .onChanged { value in
                // Stop any ongoing momentum
                momentumController?.stop()
                momentumController = nil

                // Capture starting offset on first event
                if dragStartOffset == nil {
                    dragStartOffset = canvasOffset
                }

                // Calculate velocity
                let now = Date()
                let dt = now.timeIntervalSince(lastDragTime)
                if dt > 0 && dt < 0.5 {
                    dragVelocity = CGPoint(
                        x: (value.location.x - lastDragPosition.x) / CGFloat(dt),
                        y: (value.location.y - lastDragPosition.y) / CGFloat(dt)
                    )
                }
                lastDragPosition = value.location
                lastDragTime = now

                // Fixed: base offset from drag START, not current (cumulative) offset
                let newOffset = CGPoint(
                    x: dragStartOffset!.x + value.translation.width,
                    y: dragStartOffset!.y + value.translation.height
                )

                let bounds = scaledBounds()
                canvasOffset = applyRubberBand(offset: newOffset, bounds: bounds)
            }
            .onEnded { value in
                dragStartOffset = nil
                let bounds = scaledBounds()

                // Check if beyond bounds - spring back
                let clamped = clampToBounds(offset: canvasOffset, bounds: bounds)
                if clamped != canvasOffset {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        canvasOffset = clamped
                    }
                    haptics.panBounce()
                    return
                }

                // Apply momentum
                let velocity = dragVelocity
                guard abs(velocity.x) > 100 || abs(velocity.y) > 100 else { return }

                let controller = MomentumController()
                momentumController = controller

                controller.start(
                    velocity: velocity,
                    decayRate: 0.93,
                    onUpdate: { delta in
                        let newOffset = CGPoint(
                            x: canvasOffset.x + delta.x,
                            y: canvasOffset.y + delta.y
                        )
                        let clampedNew = clampToBounds(offset: newOffset, bounds: bounds)
                        canvasOffset = clampedNew

                        // Stop if hit bounds
                        if clampedNew != newOffset {
                            momentumController?.stop()
                            haptics.panBounce()
                        }
                    },
                    onComplete: {
                        momentumController = nil
                    }
                )
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

// MARK: - Display Link Target (weak trampoline to break retain cycle)

@MainActor
private final class DisplayLinkTarget: NSObject {
    weak var controller: MomentumController?

    init(controller: MomentumController) {
        self.controller = controller
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let controller else {
            link.invalidate()
            return
        }
        controller.handleTick(link)
    }
}

// MARK: - Momentum Controller

@MainActor
final class MomentumController {
    private var displayLink: CADisplayLink?
    private var velocity: CGPoint = .zero
    private var decayRate: CGFloat = 0.95
    private var onUpdate: ((CGPoint) -> Void)?
    private var onComplete: (() -> Void)?
    private var lastTimestamp: CFTimeInterval = 0

    func start(
        velocity: CGPoint,
        decayRate: CGFloat,
        onUpdate: @escaping (CGPoint) -> Void,
        onComplete: @escaping () -> Void
    ) {
        stop()
        self.velocity = velocity
        self.decayRate = decayRate
        self.onUpdate = onUpdate
        self.onComplete = onComplete

        let target = DisplayLinkTarget(controller: self)
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func handleTick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        let dt = CGFloat(link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp

        velocity.x *= decayRate
        velocity.y *= decayRate

        let delta = CGPoint(x: velocity.x * dt, y: velocity.y * dt)
        onUpdate?(delta)

        if abs(velocity.x) < 0.5 && abs(velocity.y) < 0.5 {
            stop()
            onComplete?()
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

#Preview {
    ConstellationCanvasView(
        photos: Photo.samples,
        onPhotoTap: { _ in },
        imageLoader: { _ in nil }
    )
}
