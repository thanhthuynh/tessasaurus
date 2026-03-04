//
//  TessaAnimations.swift
//  Tessasaurus
//

import SwiftUI

enum TessaAnimations {
    static let standard: Animation = .spring(response: 0.35, dampingFraction: 0.8)
    static let quick: Animation = .spring(response: 0.3, dampingFraction: 0.8)
    static let buttonPress: Animation = .spring(response: 0.3, dampingFraction: 0.6)
    static let fanOut: Animation = .easeOut(duration: 1.5)
}
