//
//  ConfettiView.swift
//  Tessasaurus
//

import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?
    let isActive: Bool

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x,
                        y: particle.y,
                        width: particle.size,
                        height: particle.size * 1.5
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startConfetti(in: geometry.size)
                } else {
                    stopConfetti()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func startConfetti(in size: CGSize) {
        particles = []

        for _ in 0..<100 {
            let particle = ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -50,
                velocityX: CGFloat.random(in: -100...100),
                velocityY: CGFloat.random(in: 200...500),
                size: CGFloat.random(in: 6...14),
                color: confettiColors.randomElement() ?? .pink,
                rotation: CGFloat.random(in: 0...360)
            )
            particles.append(particle)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updateParticles(in: size)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            stopConfetti()
        }
    }

    private func updateParticles(in size: CGSize) {
        for i in particles.indices {
            particles[i].y += particles[i].velocityY / 60
            particles[i].x += particles[i].velocityX / 60
            particles[i].velocityY += 15
            particles[i].rotation += 5
        }

        particles.removeAll { $0.y > size.height + 50 }
    }

    private func stopConfetti() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.5)) {
            particles = []
        }
    }

    private var confettiColors: [Color] {
        [
            TessaColors.primary,
            TessaColors.pink,
            TessaColors.coral,
            TessaColors.orange,
            TessaColors.gold,
            TessaColors.primaryLight
        ]
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: CGFloat
}

struct LightRaysView: View {
    @State private var rotation: Double = 0
    let isActive: Bool

    var body: some View {
        ZStack {
            ForEach(0..<12) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [TessaColors.gold.opacity(0.6), .clear],
                            startPoint: .center,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8, height: 200)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .rotationEffect(.degrees(rotation))
        .opacity(isActive ? 1 : 0)
        .scaleEffect(isActive ? 1.5 : 0.5)
        .animation(.easeOut(duration: 0.5), value: isActive)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    ZStack {
        GradientBackground()
        LightRaysView(isActive: true)
        ConfettiView(isActive: true)
    }
}
