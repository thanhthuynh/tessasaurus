//
//  HapticService.swift
//  Tessasaurus
//

import UIKit

final class HapticService {
    static let shared = HapticService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    private func prepareAll() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    func lightTap() {
        impactLight.impactOccurred()
    }

    func mediumTap() {
        impactMedium.impactOccurred()
    }

    func heavyTap() {
        impactHeavy.impactOccurred()
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    func selection() {
        selectionGenerator.selectionChanged()
    }

    func anticipationSequence() async {
        for _ in 0..<3 {
            impactLight.impactOccurred()
            try? await Task.sleep(nanoseconds: 150_000_000)
            impactMedium.impactOccurred()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        impactHeavy.impactOccurred()
    }

    func celebrationBurst() async {
        for _ in 0..<5 {
            impactMedium.impactOccurred()
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
        notificationGenerator.notificationOccurred(.success)
    }

    func zoomSnap() {
        impactLight.impactOccurred(intensity: 0.5)
    }

    func panBounce() {
        impactLight.impactOccurred(intensity: 0.3)
    }
}
