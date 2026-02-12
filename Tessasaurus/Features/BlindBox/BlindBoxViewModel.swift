//
//  BlindBoxViewModel.swift
//  Tessasaurus
//

import Foundation
import SwiftUI

@Observable
final class BlindBoxViewModel {
    private let dateService = DateService()
    private let persistenceService = PersistenceService()
    private let hapticService = HapticService.shared

    let occasion: Occasion

    var selectedDayNumber: Int?
    var isShowingHint: Bool = false
    var isAnimatingOpen: Bool = false

    init(occasion: Occasion = .birthday) {
        self.occasion = occasion
    }

    var daysUntilTarget: Int {
        dateService.daysUntil(occasion.targetDate)
    }

    var currentDayNumber: Int? {
        dateService.currentDayNumber(for: occasion)
    }

    var isCountdownActive: Bool {
        dateService.isCountdownActive(for: occasion)
    }

    func dayStatus(for dayNumber: Int) -> DayStatus {
        dateService.dayStatus(dayNumber: dayNumber, for: occasion)
    }

    func isDayOpened(_ dayNumber: Int) -> Bool {
        persistenceService.isDayOpened(dayNumber, for: occasion.id)
    }

    func canOpen(dayNumber: Int) -> Bool {
        dateService.canOpenBox(dayNumber: dayNumber, for: occasion) && !isDayOpened(dayNumber)
    }

    func hint(for dayNumber: Int) -> GiftHint? {
        occasion.hints.first { $0.dayNumber == dayNumber }
    }

    func selectDay(_ dayNumber: Int) {
        guard canOpen(dayNumber: dayNumber) else { return }
        selectedDayNumber = dayNumber
        hapticService.selection()
    }

    func openSelectedBox() async {
        guard let dayNumber = selectedDayNumber else { return }

        isAnimatingOpen = true

        await hapticService.anticipationSequence()

        persistenceService.markDayOpened(dayNumber, for: occasion.id)

        try? await Task.sleep(nanoseconds: 600_000_000)

        await hapticService.celebrationBurst()

        isShowingHint = true
        isAnimatingOpen = false
    }

    func dismissHint() {
        isShowingHint = false
        selectedDayNumber = nil
        hapticService.lightTap()
    }
}
