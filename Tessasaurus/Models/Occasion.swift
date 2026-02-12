//
//  Occasion.swift
//  Tessasaurus
//

import Foundation

struct Occasion: Codable, Identifiable {
    let id: UUID
    let name: String
    let targetDate: Date
    let countdownDays: Int
    let hints: [GiftHint]

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -countdownDays, to: targetDate) ?? targetDate
    }
}

extension Occasion {
    static let birthday: Occasion = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 4
        let targetDate = Calendar.current.date(from: components) ?? Date()

        return Occasion(
            id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
            name: "Birthday",
            targetDate: targetDate,
            countdownDays: 7,
            hints: [
                GiftHint(dayNumber: 1, hintText: "Something cozy to keep you warm...", emoji: "🧶"),
                GiftHint(dayNumber: 2, hintText: "A little sparkle for someone special...", emoji: "✨"),
                GiftHint(dayNumber: 3, hintText: "Sweet treats to brighten your day...", emoji: "🍫"),
                GiftHint(dayNumber: 4, hintText: "Words from the heart...", emoji: "💌"),
                GiftHint(dayNumber: 5, hintText: "Relaxation awaits...", emoji: "🛁"),
                GiftHint(dayNumber: 6, hintText: "A memory to cherish forever...", emoji: "📸"),
                GiftHint(dayNumber: 7, hintText: "The big surprise is here!", emoji: "🎁")
            ]
        )
    }()
}
