//
//  StarfieldBackground.swift
//  Tessasaurus
//

import SwiftUI

struct StarfieldBackground: View {
    let canvasOffset: CGPoint

    @State private var twinklePhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let allStars: (distant: [Star], mid: [Star], near: [Star]) = {
        var distant: [Star] = []
        var mid: [Star] = []
        var near: [Star] = []

        for i in 0..<200 {
            let seed = Double(i * 48271 + 12345)
            let x = CGFloat(((sin(seed) + 1) / 2))
            let y = CGFloat(((cos(seed * 1.7) + 1) / 2))
            let baseBrightness = CGFloat(0.3 + (sin(seed * 2.3) + 1) / 2 * 0.7)

            if i < 100 {
                distant.append(Star(x: x, y: y, size: CGFloat(1.0 + sin(seed * 3.1) * 0.5), brightness: baseBrightness, phaseOffset: CGFloat(seed)))
            } else if i < 160 {
                mid.append(Star(x: x, y: y, size: CGFloat(1.5 + cos(seed * 2.7) * 0.5), brightness: baseBrightness, phaseOffset: CGFloat(seed)))
            } else {
                near.append(Star(x: x, y: y, size: CGFloat(2.0 + sin(seed * 1.9) * 1.0), brightness: baseBrightness, phaseOffset: CGFloat(seed)))
            }
        }

        return (distant, mid, near)
    }()

    var body: some View {
        Canvas { context, size in
            let time = twinklePhase * 8.0

            // Draw cosmic-sunset gradient background
            let gradientRect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(gradientRect),
                with: .linearGradient(
                    Gradient(colors: [
                        TessaColors.deepSpace,
                        TessaColors.nebula,
                        TessaColors.primary.opacity(0.8),
                        TessaColors.pink.opacity(0.7),
                        TessaColors.coral.opacity(0.6),
                        TessaColors.gold.opacity(0.5),
                        TessaColors.cream.opacity(0.4)
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )

            // Draw star layers with parallax
            drawStarLayer(context: context, size: size, stars: Self.allStars.distant, parallaxFactor: 0.1, time: time)
            drawStarLayer(context: context, size: size, stars: Self.allStars.mid, parallaxFactor: 0.3, time: time)
            drawStarLayer(context: context, size: size, stars: Self.allStars.near, parallaxFactor: 0.6, time: time)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                twinklePhase = 1.0
            }
        }
    }

    private func drawStarLayer(context: GraphicsContext, size: CGSize, stars: [Star], parallaxFactor: CGFloat, time: CGFloat) {
        for star in stars {
            let parallaxX = canvasOffset.x * parallaxFactor * 0.01
            let parallaxY = canvasOffset.y * parallaxFactor * 0.01

            // Wrap star positions so they tile
            var sx = star.x * size.width + parallaxX
            var sy = star.y * size.height + parallaxY
            sx = sx.truncatingRemainder(dividingBy: size.width)
            sy = sy.truncatingRemainder(dividingBy: size.height)
            if sx < 0 { sx += size.width }
            if sy < 0 { sy += size.height }

            // Twinkle effect
            let twinkle = CGFloat(sin(Double(time) * 1.5 + Double(star.phaseOffset)) * 0.3 + 0.7)
            let opacity = star.brightness * twinkle

            let starRect = CGRect(
                x: sx - star.size / 2,
                y: sy - star.size / 2,
                width: star.size,
                height: star.size
            )

            context.fill(
                Path(ellipseIn: starRect),
                with: .color(TessaColors.starWhite.opacity(opacity))
            )
        }
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let brightness: CGFloat
    let phaseOffset: CGFloat
}

#Preview {
    StarfieldBackground(canvasOffset: .zero)
}
