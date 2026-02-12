//
//  PersistenceService.swift
//  Tessasaurus
//

import Foundation

final class PersistenceService {
    private let userDefaults: UserDefaults
    private let openedBoxesKey = "openedBoxes"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func openedDays(for occasionID: UUID) -> Set<Int> {
        let key = "\(openedBoxesKey)_\(occasionID.uuidString)"
        guard let data = userDefaults.data(forKey: key),
              let days = try? JSONDecoder().decode(Set<Int>.self, from: data) else {
            return []
        }
        return days
    }

    func markDayOpened(_ dayNumber: Int, for occasionID: UUID) {
        var opened = openedDays(for: occasionID)
        opened.insert(dayNumber)

        let key = "\(openedBoxesKey)_\(occasionID.uuidString)"
        if let data = try? JSONEncoder().encode(opened) {
            userDefaults.set(data, forKey: key)
        }
    }

    func isDayOpened(_ dayNumber: Int, for occasionID: UUID) -> Bool {
        openedDays(for: occasionID).contains(dayNumber)
    }

    func resetAllOpenedDays(for occasionID: UUID) {
        let key = "\(openedBoxesKey)_\(occasionID.uuidString)"
        userDefaults.removeObject(forKey: key)
    }
}
