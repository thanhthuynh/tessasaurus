//
//  PhotoBubble.swift
//  Tessasaurus
//

import SwiftUI

struct PhotoBubble: View {
    let photo: Photo
    let baseSize: CGFloat
    let imageLoader: (Photo) async -> UIImage?
    var magnificationScale: CGFloat = 1.0
    var distanceFromCenter: CGFloat = 0
    let onTap: () -> Void

    @State private var loadedImage: UIImage?
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerRotation: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bubbleSize: CGFloat {
        baseSize * photo.bubbleSize.scale * magnificationScale
    }

    private var depthScale: CGFloat {
        let maxDistance: CGFloat = 400
        let normalized = min(distanceFromCenter / maxDistance, 1.0)
        return 1.0 - normalized * 0.1  // 1.0 at center, 0.9 at edge
    }

    private var glowColor: Color {
        let colors: [Color] = [TessaColors.primary, TessaColors.pink, TessaColors.coral, TessaColors.gold]
        let index = abs(photo.id.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glow aura
                Circle()
                    .fill(TessaGradients.photoGlow(color: glowColor))
                    .frame(width: bubbleSize * 1.6, height: bubbleSize * 1.6)
                    .blur(radius: 12)

                // Shadow layer
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: bubbleSize, height: bubbleSize)
                    .blur(radius: 8)
                    .offset(y: 4)

                // Photo content
                photoContent
                    .frame(width: bubbleSize, height: bubbleSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.6)
                                    ],
                                    center: .center,
                                    startAngle: .degrees(shimmerRotation),
                                    endAngle: .degrees(shimmerRotation + 360)
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: TessaColors.primary.opacity(0.3), radius: 10, x: 0, y: 4)
            }
        }
        .buttonStyle(BubbleButtonStyle())
        .scaleEffect(pulseScale * depthScale)
        .accessibilityLabel(photo.caption ?? "Photo")
        .task(id: photo.id) {
            let image = await imageLoader(photo)
            withAnimation(.easeIn(duration: 0.3)) {
                loadedImage = image
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            startIdleAnimation()
            startShimmer()
        }
    }

    @ViewBuilder
    private var photoContent: some View {
        if let uiImage = loadedImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let assetName = photo.assetImageName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderContent
        }
    }

    private var placeholderContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TessaColors.primaryLight.opacity(0.5),
                    TessaColors.pink.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo")
                .font(.system(size: bubbleSize * 0.3))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func startIdleAnimation() {
        // Deterministic values seeded from photo.id
        let hash = abs(photo.id.hashValue)
        let duration = 2.5 + Double(hash % 100) / 100.0
        let delay = Double((hash >> 8) % 100) / 100.0

        withAnimation(
            .easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
            .delay(delay)
        ) {
            pulseScale = 1.02
        }
    }

    private func startShimmer() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            shimmerRotation = 360
        }
    }
}

struct BubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Loading Bubble

struct LoadingBubble: View {
    let size: CGFloat

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        TessaColors.primaryLight.opacity(0.3),
                        TessaColors.pink.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
            )
            .opacity(isAnimating ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    ZStack {
        GradientBackground()

        VStack(spacing: 20) {
            PhotoBubble(
                photo: Photo.samples[0],
                baseSize: 120,
                imageLoader: { _ in nil },
                onTap: {}
            )

            PhotoBubble(
                photo: Photo.samples[1],
                baseSize: 120,
                imageLoader: { _ in nil },
                onTap: {}
            )

            LoadingBubble(size: 100)
        }
    }
}
