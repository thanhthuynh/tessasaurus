//
//  HomeView.swift
//  Tessasaurus
//

import SwiftUI

struct HomeView: View {
    @State private var showBlindBox = false
    @State private var showWelcome = false
    @State private var showOccasion = false
    @State private var showTeaser = false
    private let dateService = DateService()
    private let occasion = Occasion.birthday

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground()

                ScrollView {
                    VStack(spacing: 32) {
                        welcomeSection
                            .padding(.top, 40)
                            .offset(y: showWelcome ? 0 : 30)
                            .opacity(showWelcome ? 1 : 0)

                        occasionCard
                            .offset(y: showOccasion ? 0 : 30)
                            .opacity(showOccasion ? 1 : 0)

                        photoTeaser
                            .offset(y: showTeaser ? 0 : 30)
                            .opacity(showTeaser ? 1 : 0)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationDestination(isPresented: $showBlindBox) {
                BlindBoxView()
            }
            .onAppear {
                animateEntrance()
            }
        }
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.5)) {
            showWelcome = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            showOccasion = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.30)) {
            showTeaser = true
        }
    }

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Text(greetingText)
                .font(TessaTypography.sectionTitle)
                .foregroundStyle(.white.opacity(0.9))

            Text("Tessa")
                .font(TessaTypography.heroTitle)
                .foregroundStyle(TessaGradients.sunrise)
                .shimmer()

            Text(loveMessage)
                .font(TessaTypography.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var occasionCard: some View {
        Button(action: {
            showBlindBox = true
        }) {
            GlassCard {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(occasion.name)
                                .font(TessaTypography.cardTitle)
                                .foregroundStyle(.white)

                            if dateService.isCountdownActive(for: occasion) {
                                Text("ACTIVE")
                                    .font(TessaTypography.badge)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(TessaColors.coral)
                                    )
                            }
                        }

                        Text(countdownText)
                            .font(TessaTypography.body)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Tap to open your daily gift")
                            .font(TessaTypography.caption)
                            .foregroundStyle(TessaColors.gold)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(TessaGradients.sunrise)
                            .frame(width: 56, height: 56)

                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var photoTeaser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our Memories")
                .font(TessaTypography.cardTitle)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            GlassCard {
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 8)
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
                            .aspectRatio(0.8, contentMode: .fit)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }
                }
                .frame(height: 80)
            }

            Text("Switch to the Photos tab to see all memories")
                .font(TessaTypography.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 4)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<21: return "Good evening,"
        default: return "Sweet dreams,"
        }
    }

    private var loveMessage: String {
        let messages = [
            "Every moment with you is a gift",
            "You make every day brighter",
            "My heart belongs to you",
            "You are my everything"
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return messages[dayOfYear % messages.count]
    }

    private var countdownText: String {
        let days = dateService.daysUntil(occasion.targetDate)
        if days <= 0 {
            return "Happy \(occasion.name)!"
        } else if days == 1 {
            return "1 day until \(occasion.name.lowercased())"
        } else {
            return "\(days) days until \(occasion.name.lowercased())"
        }
    }
}

#Preview {
    HomeView()
}
