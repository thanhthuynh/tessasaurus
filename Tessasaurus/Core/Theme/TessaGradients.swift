//
//  TessaGradients.swift
//  Tessasaurus
//

import SwiftUI

enum TessaGradients {
    // Main aurora background gradient
    static let aurora = LinearGradient(
        colors: [
            TessaColors.primary,
            TessaColors.primaryLight,
            TessaColors.pink,
            TessaColors.cream
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Sunrise gradient for headers and accents
    static let sunrise = LinearGradient(
        colors: [
            TessaColors.coral,
            TessaColors.orange,
            TessaColors.gold
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Gift box gradient
    static let giftBox = LinearGradient(
        colors: [
            TessaColors.primary,
            TessaColors.primaryDark
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Ribbon gradient
    static let ribbon = LinearGradient(
        colors: [
            TessaColors.gold,
            TessaColors.orange
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Glass card gradient
    static let glass = LinearGradient(
        colors: [
            Color.white.opacity(0.25),
            Color.white.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Cosmic-to-sunset gradient for constellation canvas
    static let cosmicSunset = LinearGradient(
        colors: [
            TessaColors.deepSpace,
            TessaColors.nebula,
            TessaColors.primary,
            TessaColors.pink,
            TessaColors.coral,
            TessaColors.gold,
            TessaColors.cream
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Radial glow for photo bubbles
    static func photoGlow(color: Color = TessaColors.primary) -> RadialGradient {
        RadialGradient(
            colors: [
                color.opacity(0.3),
                color.opacity(0.1),
                color.opacity(0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 60
        )
    }

    // Vertical aurora for backgrounds
    static let auroraVertical = LinearGradient(
        colors: [
            TessaColors.primary.opacity(0.8),
            TessaColors.pink.opacity(0.6),
            TessaColors.coral.opacity(0.4),
            TessaColors.cream.opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
