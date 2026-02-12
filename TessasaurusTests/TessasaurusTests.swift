//
//  TessasaurusTests.swift
//  TessasaurusTests
//
//  Created by Thanh Huynh on 1/28/26.
//

import Testing
import Foundation
@testable import Tessasaurus

struct DateServiceTests {
    let dateService = DateService()

    @Test func daysUntilReturnsPositiveForFutureDate() async throws {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let days = dateService.daysUntil(future)
        #expect(days == 5)
    }

    @Test func daysUntilReturnsZeroForToday() async throws {
        let today = Date()
        let days = dateService.daysUntil(today)
        #expect(days == 0)
    }

    @Test func daysUntilReturnsNegativeForPastDate() async throws {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let days = dateService.daysUntil(past)
        #expect(days == -3)
    }

    @Test func currentDayNumberReturnsDayDuringCountdown() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .day, value: 3, to: today)!

        let occasion = Occasion(
            id: UUID(),
            name: "Test",
            targetDate: targetDate,
            countdownDays: 7,
            hints: []
        )

        let currentDay = dateService.currentDayNumber(for: occasion)
        #expect(currentDay == 5)
    }

    @Test func isCountdownActiveReturnsTrueDuringCountdown() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .day, value: 3, to: today)!

        let occasion = Occasion(
            id: UUID(),
            name: "Test",
            targetDate: targetDate,
            countdownDays: 7,
            hints: []
        )

        #expect(dateService.isCountdownActive(for: occasion))
    }

    @Test func isCountdownActiveReturnsFalseBeforeCountdown() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .day, value: 30, to: today)!

        let occasion = Occasion(
            id: UUID(),
            name: "Test",
            targetDate: targetDate,
            countdownDays: 7,
            hints: []
        )

        #expect(!dateService.isCountdownActive(for: occasion))
    }
}

struct PersistenceServiceTests {
    @Test func markDayOpenedPersistsCorrectly() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let occasionID = UUID()

        service.markDayOpened(3, for: occasionID)

        #expect(service.isDayOpened(3, for: occasionID))
        #expect(!service.isDayOpened(2, for: occasionID))

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }

    @Test func openedDaysReturnsAllOpenedDays() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let occasionID = UUID()

        service.markDayOpened(1, for: occasionID)
        service.markDayOpened(3, for: occasionID)
        service.markDayOpened(5, for: occasionID)

        let opened = service.openedDays(for: occasionID)
        #expect(opened == [1, 3, 5])

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }

    @Test func resetClearsAllOpenedDays() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let occasionID = UUID()

        service.markDayOpened(1, for: occasionID)
        service.markDayOpened(2, for: occasionID)
        service.resetAllOpenedDays(for: occasionID)

        #expect(service.openedDays(for: occasionID).isEmpty)

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }
}
