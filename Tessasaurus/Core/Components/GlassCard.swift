//
//  GlassCard.swift
//  Tessasaurus
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(TessaColors.cardBorder, lineWidth: 1)
                    )
            )
            .shadow(color: TessaColors.primary.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ZStack {
        GradientBackground()
        GlassCard {
            VStack(spacing: 12) {
                Text("Glass Card")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Beautiful glassmorphism effect")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
    }
}
