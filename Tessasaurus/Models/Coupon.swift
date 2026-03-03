//
//  Coupon.swift
//  Tessasaurus
//

import SwiftUI

struct Coupon: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let emoji: String
    let totalUses: Int?
    let smsLabel: String
    let accentColors: (Color, Color)

    var isInfinite: Bool { totalUses == nil }

    static func smsURL(for coupon: Coupon) -> URL? {
        let body = "Tessa would like to redeem: \(coupon.name)!"
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "sms:+16107049840&body=\(encoded)")
    }
}

extension Coupon {
    static let allCoupons: [Coupon] = [
        Coupon(
            id: UUID(uuidString: "C00A0001-0000-0000-0000-000000000001")!,
            name: "Kisses & Hugs",
            description: "Redeemable anytime, anywhere",
            emoji: "\u{1F48B}",
            totalUses: nil,
            smsLabel: "Kisses & Hugs",
            accentColors: (TessaColors.pink, TessaColors.coral)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0002-0000-0000-0000-000000000002")!,
            name: "Free Massage",
            description: "A relaxing massage, no questions asked",
            emoji: "\u{1F486}\u{200D}\u{2640}\u{FE0F}",
            totalUses: 5,
            smsLabel: "Free Massage",
            accentColors: (TessaColors.primaryLight, TessaColors.primary)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0003-0000-0000-0000-000000000003")!,
            name: "Get Out of Jail Free",
            description: "Instant forgiveness for anything small",
            emoji: "\u{1F513}",
            totalUses: 3,
            smsLabel: "Get Out of Jail Free",
            accentColors: (TessaColors.gold, TessaColors.orange)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0004-0000-0000-0000-000000000004")!,
            name: "Date of Her Choice",
            description: "You pick the place, I'll make it happen",
            emoji: "\u{1F339}",
            totalUses: 3,
            smsLabel: "Date of Her Choice",
            accentColors: (TessaColors.coral, TessaColors.pink)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0005-0000-0000-0000-000000000005")!,
            name: "Breakfast in Bed",
            description: "Wake up to your favorite meal",
            emoji: "\u{1F373}",
            totalUses: 3,
            smsLabel: "Breakfast in Bed",
            accentColors: (TessaColors.orange, TessaColors.gold)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0006-0000-0000-0000-000000000006")!,
            name: "Movie Night",
            description: "Your pick, plus all the snacks",
            emoji: "\u{1F3AC}",
            totalUses: 5,
            smsLabel: "Movie Night (Her Pick)",
            accentColors: (TessaColors.primary, TessaColors.primaryLight)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0007-0000-0000-0000-000000000007")!,
            name: "No Phone Hour",
            description: "One full hour of undivided attention",
            emoji: "\u{1F4F5}",
            totalUses: 5,
            smsLabel: "No Phone Hour",
            accentColors: (TessaColors.coral, TessaColors.orange)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0008-0000-0000-0000-000000000008")!,
            name: "Spa Day at Home",
            description: "Full pampering session, just for you",
            emoji: "\u{1F9D6}\u{200D}\u{2640}\u{FE0F}",
            totalUses: 2,
            smsLabel: "Spa Day at Home",
            accentColors: (TessaColors.pink, TessaColors.primaryLight)
        ),
        Coupon(
            id: UUID(uuidString: "C00A0009-0000-0000-0000-000000000009")!,
            name: "Cook Her Favorite Meal",
            description: "Chef Thanh at your service",
            emoji: "\u{1F468}\u{200D}\u{1F373}",
            totalUses: 3,
            smsLabel: "Cook Her Favorite Meal",
            accentColors: (TessaColors.orange, TessaColors.coral)
        ),
        Coupon(
            id: UUID(uuidString: "C00A000A-0000-0000-0000-00000000000A")!,
            name: "Love Letter on Demand",
            description: "A heartfelt letter, whenever you want one",
            emoji: "\u{1F48C}",
            totalUses: 5,
            smsLabel: "Love Letter on Demand",
            accentColors: (TessaColors.pink, TessaColors.gold)
        ),
    ]
}
