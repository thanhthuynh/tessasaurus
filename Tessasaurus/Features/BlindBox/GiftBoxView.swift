//
//  GiftBoxView.swift
//  Tessasaurus
//

import SwiftUI

struct GiftBoxView: View {
    let dayNumber: Int
    let status: DayStatus
    let isOpened: Bool
    let isAnimating: Bool

    @State private var lidRotation: Double = 0
    @State private var boxScale: CGFloat = 1.0
    @State private var isShaking: Bool = false

    var body: some View {
        ZStack {
            boxBody
            lid
            dayLabel
        }
        .scaleEffect(boxScale)
        .modifier(ShakeEffect(shakes: isShaking ? 6 : 0))
        .onChange(of: isAnimating) { _, animating in
            if animating {
                startOpenAnimation()
            }
        }
        .onChange(of: isOpened) { _, opened in
            if opened && !isAnimating {
                lidRotation = -110
                boxScale = 0.9
            }
        }
        .onAppear {
            if isOpened {
                lidRotation = -110
                boxScale = 0.9
            }
        }
    }

    private var boxBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(TessaGradients.giftBox)
                .frame(width: 100, height: 80)
                .offset(y: 15)

            Rectangle()
                .fill(TessaGradients.ribbon)
                .frame(width: 20, height: 80)
                .offset(y: 15)

            Rectangle()
                .fill(TessaGradients.ribbon)
                .frame(width: 100, height: 15)
                .offset(y: 15)
        }
        .opacity(status == .locked ? 0.4 : 1.0)
    }

    private var lid: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(TessaGradients.giftBox)
                .frame(width: 110, height: 25)

            Rectangle()
                .fill(TessaGradients.ribbon)
                .frame(width: 22, height: 25)

            bow
                .offset(y: -20)
        }
        .offset(y: -30)
        .rotation3DEffect(
            .degrees(lidRotation),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.3
        )
        .opacity(status == .locked ? 0.4 : 1.0)
    }

    private var bow: some View {
        ZStack {
            Ellipse()
                .fill(TessaGradients.ribbon)
                .frame(width: 25, height: 20)
                .offset(x: -12)
                .rotationEffect(.degrees(-20))

            Ellipse()
                .fill(TessaGradients.ribbon)
                .frame(width: 25, height: 20)
                .offset(x: 12)
                .rotationEffect(.degrees(20))

            Circle()
                .fill(TessaColors.gold)
                .frame(width: 15, height: 15)
        }
    }

    private var dayLabel: some View {
        Text("\(dayNumber)")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .offset(y: 20)
            .opacity(status == .locked ? 0.5 : 1.0)
    }

    private func startOpenAnimation() {
        withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
            isShaking = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isShaking = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                lidRotation = -110
                boxScale = 0.9
            }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(shakes * .pi * 2) * 5
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    VStack(spacing: 40) {
        GiftBoxView(dayNumber: 1, status: .unlocked, isOpened: false, isAnimating: false)
        GiftBoxView(dayNumber: 2, status: .current, isOpened: false, isAnimating: false)
        GiftBoxView(dayNumber: 3, status: .locked, isOpened: false, isAnimating: false)
        GiftBoxView(dayNumber: 4, status: .unlocked, isOpened: true, isAnimating: false)
    }
    .padding()
    .background(GradientBackground())
}
