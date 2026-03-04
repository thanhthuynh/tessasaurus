//
//  GradientBackground.swift
//  Tessasaurus
//

import SwiftUI

struct GradientBackground: View {
    @State private var animateGradient = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [animateGradient ? 0.6 : 0.4, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                TessaColors.primary, TessaColors.primaryLight, TessaColors.pink,
                TessaColors.primaryLight, TessaColors.pink, TessaColors.coral,
                TessaColors.pink, TessaColors.coral, TessaColors.cream
            ]
        )
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

#Preview {
    GradientBackground()
}
