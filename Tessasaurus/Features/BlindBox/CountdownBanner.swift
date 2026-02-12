//
//  CountdownBanner.swift
//  Tessasaurus
//

import SwiftUI

struct CountdownBanner: View {
    let daysRemaining: Int
    let occasionName: String

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(countdownText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(TessaGradients.sunrise)
                        .frame(width: 60, height: 60)

                    Text("\(max(0, daysRemaining))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal)
    }

    private var countdownText: String {
        if daysRemaining <= 0 {
            return "Happy \(occasionName)!"
        } else if daysRemaining == 1 {
            return "1 day to go!"
        } else {
            return "\(daysRemaining) days to go!"
        }
    }

    private var subtitleText: String {
        if daysRemaining <= 0 {
            return "Your special day is here"
        } else {
            return "Until your \(occasionName.lowercased())"
        }
    }
}

#Preview {
    ZStack {
        GradientBackground()
        VStack(spacing: 20) {
            CountdownBanner(daysRemaining: 5, occasionName: "Birthday")
            CountdownBanner(daysRemaining: 1, occasionName: "Birthday")
            CountdownBanner(daysRemaining: 0, occasionName: "Birthday")
        }
    }
}
