//
//  OnboardingMessages.swift
//  Tessasaurus
//

import Foundation

struct OnboardingMessage {
    let chinese: String
    let english: String
}

enum OnboardingContent {
    static let titleCharacters = "\u{9EC4}\u{7406}\u{592E}"
    static let tapPrompt = "tap to enter"

    static let messages: [OnboardingMessage] = [
        OnboardingMessage(chinese: "placeholder", english: "Placeholder message 1"),
        OnboardingMessage(chinese: "placeholder", english: "Placeholder message 2"),
        OnboardingMessage(chinese: "placeholder", english: "Placeholder message 3"),
    ]
}
