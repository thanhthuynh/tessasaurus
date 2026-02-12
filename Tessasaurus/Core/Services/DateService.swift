//
//  DateService.swift
//  Tessasaurus
//

import Foundation

struct DateService {
    private let calendar = Calendar.current

    func daysUntil(_ date: Date) -> Int {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    func currentDayNumber(for occasion: Occasion) -> Int? {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: occasion.startDate)
        let target = calendar.startOfDay(for: occasion.targetDate)

        guard today >= start && today <= target else { return nil }

        let daysSinceStart = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return daysSinceStart + 1
    }

    func isCountdownActive(for occasion: Occasion) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: occasion.startDate)
        let target = calendar.startOfDay(for: occasion.targetDate)

        return today >= start && today <= target
    }

    func dayStatus(dayNumber: Int, for occasion: Occasion) -> DayStatus {
        guard let currentDay = currentDayNumber(for: occasion) else {
            let daysUntilTarget = daysUntil(occasion.targetDate)
            if daysUntilTarget > occasion.countdownDays {
                return .locked
            } else {
                return .unlocked
            }
        }

        if dayNumber < currentDay {
            return .unlocked
        } else if dayNumber == currentDay {
            return .current
        } else {
            return .locked
        }
    }

    func canOpenBox(dayNumber: Int, for occasion: Occasion) -> Bool {
        let status = dayStatus(dayNumber: dayNumber, for: occasion)
        return status == .unlocked || status == .current
    }
}

enum DayStatus {
    case locked
    case current
    case unlocked
}
