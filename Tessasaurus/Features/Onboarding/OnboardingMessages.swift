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
        OnboardingMessage(chinese: "生日快乐宝贝！", english: "Happy Birthday baby!"),
        OnboardingMessage(chinese: "这个app是为你而做的…", english: "I dedicate this app to you..."),
        OnboardingMessage(chinese: "现在还很简单…", english: "It's simple right now..."),
        OnboardingMessage(chinese: "但会越来越好的，相信我", english: "but will get better with time, trust me"),
        OnboardingMessage(chinese: "希望你喜欢…", english: "Hope you like this and..."),
        OnboardingMessage(chinese: "我爱你！", english: "I love you!"),
    ]
}
