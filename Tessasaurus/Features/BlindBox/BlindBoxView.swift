//
//  BlindBoxView.swift
//  Tessasaurus
//

import SwiftUI

struct BlindBoxView: View {
    @State private var viewModel = BlindBoxViewModel()
    @Namespace private var animation

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 32) {
                headerSection

                Spacer()

                ZStack {
                    LightRaysView(isActive: viewModel.isShowingHint)
                    giftBoxSection
                }

                Spacer()

                DayProgressView(
                    totalDays: viewModel.occasion.countdownDays,
                    currentDay: viewModel.currentDayNumber,
                    openedDays: Set(viewModel.occasion.hints.filter { viewModel.isDayOpened($0.dayNumber) }.map(\.dayNumber)),
                    dayStatus: { viewModel.dayStatus(for: $0) },
                    onDayTap: { day in
                        viewModel.selectDay(day)
                    }
                )
                .padding(.bottom, 40)
            }

            ConfettiView(isActive: viewModel.isShowingHint)

            if viewModel.isShowingHint, let dayNumber = viewModel.selectedDayNumber,
               let hint = viewModel.hint(for: dayNumber) {
                hintOverlay(hint: hint)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Birthday Countdown")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .padding(.top, 20)

            CountdownBanner(
                daysRemaining: viewModel.daysUntilTarget,
                occasionName: viewModel.occasion.name
            )
        }
    }

    private var giftBoxSection: some View {
        VStack(spacing: 24) {
            if let selectedDay = viewModel.selectedDayNumber {
                GiftBoxView(
                    dayNumber: selectedDay,
                    status: viewModel.dayStatus(for: selectedDay),
                    isOpened: viewModel.isDayOpened(selectedDay),
                    isAnimating: viewModel.isAnimatingOpen
                )
                .scaleEffect(1.5)
                .matchedGeometryEffect(id: "box-\(selectedDay)", in: animation)

                if !viewModel.isDayOpened(selectedDay) && !viewModel.isAnimatingOpen {
                    Button(action: {
                        Task {
                            await viewModel.openSelectedBox()
                        }
                    }) {
                        Text("Tap to Open")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(TessaGradients.sunrise)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                instructionText
            }
        }
        .animation(.spring(response: 0.4), value: viewModel.selectedDayNumber)
    }

    private var instructionText: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 48))
                .foregroundStyle(TessaGradients.sunrise)

            Text("Select a day below")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
    }

    private func hintOverlay(hint: GiftHint) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissHint()
                }

            HintRevealView(hint: hint)
                .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.isShowingHint)
    }
}

struct HintRevealView: View {
    let hint: GiftHint
    @State private var showText = false

    var body: some View {
        GlassCard {
            VStack(spacing: 24) {
                Text(hint.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(showText ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: showText)

                Text("Day \(hint.dayNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showText ? 1 : 0)

                Text(hint.hintText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 20)

                Text("Tap anywhere to close")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
                    .opacity(showText ? 1 : 0)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
        }
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showText = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlindBoxView()
    }
}
