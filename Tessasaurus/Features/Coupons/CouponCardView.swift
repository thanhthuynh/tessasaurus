//
//  CouponCardView.swift
//  Tessasaurus
//

import SwiftUI

struct CouponCardView: View {
    let coupon: Coupon
    let remainingUses: Int?
    let isRedeemable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack(spacing: 16) {
                    emojiCircle
                    couponInfo
                    Spacer()
                    usesIndicator
                }
            }
            .opacity(isRedeemable ? 1 : 0.4)
            .overlay(alignment: .topTrailing) {
                if !isRedeemable {
                    Text("REDEEMED")
                        .font(TessaTypography.badge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                        .padding(12)
                }
            }
        }
        .buttonStyle(CouponButtonStyle())
        .disabled(!isRedeemable)
        .accessibilityLabel("\(coupon.name). \(coupon.description). \(accessibilityUsesText)")
        .accessibilityHint(isRedeemable ? "Double tap to redeem" : "Fully redeemed")
    }

    private var emojiCircle: some View {
        ZStack {
            Circle()
                .fill(
                    isRedeemable
                    ? LinearGradient(
                        colors: [coupon.accentColors.0, coupon.accentColors.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            Text(coupon.emoji)
                .font(.system(size: 28))
        }
    }

    private var couponInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(coupon.name)
                .font(TessaTypography.cardTitle)
                .foregroundStyle(TessaColors.textPrimary)
                .lineLimit(2)

            Text(coupon.description)
                .font(TessaTypography.caption)
                .foregroundStyle(TessaColors.textSecondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var usesIndicator: some View {
        if coupon.isInfinite {
            VStack(spacing: 2) {
                Image(systemName: "infinity")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TessaGradients.sunrise)
                Text("unlimited")
                    .font(TessaTypography.badge)
                    .foregroundStyle(.white.opacity(0.6))
            }
        } else if let remaining = remainingUses {
            VStack(spacing: 2) {
                Text("\(remaining)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TessaGradients.sunrise)
                Text("left")
                    .font(TessaTypography.badge)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var accessibilityUsesText: String {
        if coupon.isInfinite {
            return "Unlimited uses"
        } else if let remaining = remainingUses {
            return "\(remaining) \(remaining == 1 ? "use" : "uses") remaining"
        }
        return ""
    }
}

struct CouponButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
