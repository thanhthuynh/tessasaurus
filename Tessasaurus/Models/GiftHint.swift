//
//  GiftHint.swift
//  Tessasaurus
//

import Foundation

struct GiftHint: Codable, Identifiable {
    let dayNumber: Int
    let hintText: String
    let emoji: String

    var id: Int { dayNumber }
}
