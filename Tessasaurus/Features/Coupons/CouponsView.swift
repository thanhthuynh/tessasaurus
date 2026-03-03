//
//  CouponsView.swift
//  Tessasaurus
//

import SwiftUI

struct CouponsView: View {
    @State private var viewModel = CouponsViewModel()
    @State private var headerAppeared = false
    @State private var sectionAppeared = false
    @State private var cardAppeared: Set<UUID> = []
    @State private var overlayContentVisible = false

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 40)
                        .offset(y: headerAppeared ? 0 : 30)
                        .opacity(headerAppeared ? 1 : 0)

                    couponSectionHeader
                        .offset(y: sectionAppeared ? 0 : 30)
                        .opacity(sectionAppeared ? 1 : 0)

                    couponList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }

            if viewModel.showRedeemConfirmation, let coupon = viewModel.selectedCoupon {
                redeemConfirmationOverlay(for: coupon)
                    .transition(.opacity)
            }

            ConfettiView(isActive: viewModel.showCelebration)

            if viewModel.showToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.showRedeemConfirmation)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.showToast)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text(greetingText)
                .font(TessaTypography.sectionTitle)
                .foregroundStyle(.white.opacity(0.9))

            Text("Tessa")
                .font(TessaTypography.heroTitle)
                .foregroundStyle(TessaGradients.sunrise)
                .shimmer()

            Text(subtitle)
                .font(TessaTypography.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Section Header

    private var couponSectionHeader: some View {
        HStack {
            Text("Your Coupons")
                .font(TessaTypography.cardTitle)
                .foregroundStyle(.white)

            Spacer()

            Text("\(viewModel.availableCount) available")
                .font(TessaTypography.caption)
                .foregroundStyle(TessaColors.gold)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Coupon List

    private var couponList: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.sortedCoupons) { coupon in
                CouponCardView(
                    coupon: coupon,
                    remainingUses: viewModel.remainingUses(for: coupon),
                    isRedeemable: viewModel.canRedeem(coupon),
                    onTap: { viewModel.selectCoupon(coupon) }
                )
                .offset(y: cardAppeared.contains(coupon.id) ? 0 : 30)
                .opacity(cardAppeared.contains(coupon.id) ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.sortedCoupons.map { viewModel.canRedeem($0) })
    }

    // MARK: - Confirmation Overlay

    private func redeemConfirmationOverlay(for coupon: Coupon) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissConfirmation() }

            GlassCard {
                VStack(spacing: 24) {
                    Text(coupon.emoji)
                        .font(.system(size: 80))
                        .scaleEffect(overlayContentVisible ? 1 : 0)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6).delay(0.1),
                            value: overlayContentVisible
                        )

                    Text(coupon.name)
                        .font(TessaTypography.sectionTitle)
                        .foregroundStyle(.white)
                        .opacity(overlayContentVisible ? 1 : 0)
                        .offset(y: overlayContentVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: overlayContentVisible)

                    remainingUsesDisplay(for: coupon)
                        .opacity(overlayContentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: overlayContentVisible)

                    Text("Are you sure you want to\nredeem this coupon?")
                        .font(TessaTypography.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(overlayContentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.25), value: overlayContentVisible)

                    HStack(spacing: 16) {
                        Button {
                            viewModel.dismissConfirmation()
                        } label: {
                            Text("Cancel")
                                .font(TessaTypography.cardTitle)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(Capsule().stroke(TessaColors.cardBorder, lineWidth: 1))
                                )
                        }

                        Button {
                            viewModel.confirmRedemption()
                        } label: {
                            Text("Redeem")
                                .font(TessaTypography.cardTitle)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(TessaGradients.sunrise)
                                )
                        }
                    }
                    .opacity(overlayContentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: overlayContentVisible)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 32)
        }
        .onAppear { overlayContentVisible = true }
        .onDisappear { overlayContentVisible = false }
    }

    private func remainingUsesDisplay(for coupon: Coupon) -> some View {
        HStack(spacing: 8) {
            if coupon.isInfinite {
                Image(systemName: "infinity")
                    .foregroundStyle(TessaColors.gold)
                Text("Unlimited uses")
                    .font(TessaTypography.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else if let remaining = viewModel.remainingUses(for: coupon) {
                Text("\(remaining)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(TessaColors.gold)
                Text(remaining == 1 ? "use remaining" : "uses remaining")
                    .font(TessaTypography.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        VStack {
            Text(viewModel.toastMessage)
                .font(TessaTypography.cardTitle)
                .foregroundStyle(TessaGradients.sunrise)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(TessaColors.cardBorder, lineWidth: 1))
                )
                .padding(.top, 60)

            Spacer()
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.5)) {
            headerAppeared = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            sectionAppeared = true
        }
        for (index, coupon) in viewModel.sortedCoupons.enumerated() {
            withAnimation(.easeOut(duration: 0.5).delay(0.3 + Double(index) * 0.06)) {
                cardAppeared.insert(coupon.id)
            }
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<21: return "Good evening,"
        default: return "Sweet dreams,"
        }
    }

    private var subtitle: String {
        let messages = [
            "Redeem a little love today",
            "These are all yours, always",
            "Pick something special",
            "You deserve it all"
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return messages[dayOfYear % messages.count]
    }
}

#Preview {
    CouponsView()
}
