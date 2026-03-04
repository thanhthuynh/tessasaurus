//
//  OnboardingView.swift
//  Tessasaurus
//

import SwiftUI

// MARK: - Onboarding Phase

enum OnboardingPhase: Equatable {
    case title
    case messages(Int)
    case transitioning
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: OnboardingPhase = .title
    @State private var titleOpacity: CGFloat = 1.0
    @State private var messageOpacity: CGFloat = 0.0
    @State private var canAdvance = true
    @State private var dismissOpacity: CGFloat = 1.0
    @State private var gradientOffset: CGFloat = 0
    @State private var transitionStarBrightness: CGFloat = 0

    private let totalMessages = OnboardingContent.messages.count

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                switch phase {
                case .title:
                    titleScreen

                case .messages(let index):
                    messageScreen(index: index, size: geometry.size)

                case .transitioning:
                    transitionScreen(size: geometry.size)
                }
            }
            .opacity(dismissOpacity)
            .allowsHitTesting(dismissOpacity > 0)
        }
        .ignoresSafeArea()
    }

    // MARK: - Phase A: Title Screen

    private var titleScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text(OnboardingContent.titleCharacters)
                    .font(.system(size: 52, weight: .thin, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(12)

                Text(OnboardingContent.tapPrompt)
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .modifier(PulseModifier(reduceMotion: reduceMotion))
            }
            .opacity(titleOpacity)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("Tap to continue")
        .onTapGesture {
            guard canAdvance else { return }
            canAdvance = false

            let duration = reduceMotion ? 0.01 : 0.8
            withAnimation(.easeOut(duration: duration)) {
                titleOpacity = 0
            } completion: {
                phase = .messages(0)
                messageOpacity = 0
                let fadeIn = reduceMotion ? 0.01 : 0.9
                withAnimation(.easeIn(duration: fadeIn)) {
                    messageOpacity = 1
                } completion: {
                    canAdvance = true
                }
            }
        }
    }

    // MARK: - Phase B: Message Screen

    private func messageScreen(index: Int, size: CGSize) -> some View {
        let starBrightness = CGFloat(index + 1) / CGFloat(totalMessages + 1)

        return ZStack {
            Color.black.ignoresSafeArea()

            OnboardingStarCanvas(brightness: starBrightness, reduceMotion: reduceMotion)
                .ignoresSafeArea()

            messageContent(index: index)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("Tap to continue")
        .onTapGesture {
            guard canAdvance else { return }
            canAdvance = false

            HapticService.shared.lightTap()

            let fadeOut = reduceMotion ? 0.01 : 0.7
            withAnimation(.easeOut(duration: fadeOut)) {
                messageOpacity = 0
            } completion: {
                let nextIndex = index + 1
                if nextIndex < totalMessages {
                    phase = .messages(nextIndex)
                    let fadeIn = reduceMotion ? 0.01 : 1.0
                    withAnimation(.easeIn(duration: fadeIn)) {
                        messageOpacity = 1
                    } completion: {
                        canAdvance = true
                    }
                } else {
                    // Last message done — begin transition
                    transitionStarBrightness = starBrightness
                    phase = .transitioning
                    beginTransition(screenHeight: size.height)
                }
            }
        }
    }

    private func messageContent(index: Int) -> some View {
        let message = OnboardingContent.messages[index]

        return VStack(spacing: 8) {
            Text(message.chinese)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message.english)
                .font(.system(size: 15, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .opacity(messageOpacity)
    }

    // MARK: - Phase C: Transition Screen

    private func transitionScreen(size: CGSize) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            OnboardingStarCanvas(brightness: transitionStarBrightness, reduceMotion: reduceMotion)
                .ignoresSafeArea()

            // Cosmic sunset gradient — slides up from below viewport
            LinearGradient(
                colors: [
                    TessaColors.cream.opacity(0.4),
                    TessaColors.gold.opacity(0.5),
                    TessaColors.coral.opacity(0.6),
                    TessaColors.pink.opacity(0.7),
                    TessaColors.primary.opacity(0.8),
                    TessaColors.nebula,
                    TessaColors.deepSpace,
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: size.height * 1.8)
            .offset(y: gradientOffset)
            .ignoresSafeArea()
        }
    }

    // MARK: - Transition Logic

    private func beginTransition(screenHeight: CGFloat) {
        // Position gradient below the viewport
        gradientOffset = screenHeight

        // Step 1: Stars reach full brightness
        let starDuration = reduceMotion ? 0.01 : 0.8
        withAnimation(.easeInOut(duration: starDuration)) {
            transitionStarBrightness = 1.0
        } completion: {
            // Step 2: Gradient rises from below while stars dim
            let gradientDuration = reduceMotion ? 0.01 : 3.0
            withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: gradientDuration)) {
                gradientOffset = -screenHeight * 0.8
            }
            withAnimation(.easeOut(duration: gradientDuration)) {
                transitionStarBrightness = 0.15
            } completion: {
                // Step 3: Dissolve out — crossfade into matching starfield behind
                NotificationCenter.default.post(name: .onboardingWillDismiss, object: nil)
                HapticService.shared.success()

                let dissolveDuration = reduceMotion ? 0.01 : 1.5
                withAnimation(.easeOut(duration: dissolveDuration)) {
                    dismissOpacity = 0
                } completion: {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.7 : 0.4)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Onboarding Star Canvas

private struct OnboardingStarCanvas: View {
    let brightness: CGFloat
    let reduceMotion: Bool

    @State private var twinklePhase: CGFloat = 0

    private static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, baseBrightness: CGFloat, phaseOffset: CGFloat)] = {
        (0..<200).map { i in
            let seed = Double(i * 48271 + 12345)
            let x = CGFloat((sin(seed) + 1) / 2)
            let y = CGFloat((cos(seed * 1.7) + 1) / 2)
            let baseBrightness = CGFloat(0.3 + (sin(seed * 2.3) + 1) / 2 * 0.7)
            let size: CGFloat
            if i < 100 {
                size = CGFloat(1.0 + sin(seed * 3.1) * 0.5)
            } else if i < 160 {
                size = CGFloat(1.5 + cos(seed * 2.7) * 0.5)
            } else {
                size = CGFloat(2.0 + sin(seed * 1.9) * 1.0)
            }
            return (x, y, size, baseBrightness, CGFloat(seed))
        }
    }()

    var body: some View {
        Canvas { context, size in
            let time = twinklePhase * 8.0

            for star in Self.stars {
                let sx = star.x * size.width
                let sy = star.y * size.height

                let twinkle = CGFloat(sin(Double(time) * 1.5 + Double(star.phaseOffset)) * 0.3 + 0.7)
                let opacity = star.baseBrightness * twinkle * brightness

                let rect = CGRect(
                    x: sx - star.size / 2,
                    y: sy - star.size / 2,
                    width: star.size,
                    height: star.size
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(TessaColors.starWhite.opacity(opacity))
                )
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                twinklePhase = 1.0
            }
        }
    }
}

#Preview {
    OnboardingView()
}
