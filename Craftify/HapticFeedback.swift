//
//  HapticFeedback.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 28/07/2026.
//

import UIKit

/// A single, prepared entry point for tactile feedback throughout Craftify.
///
/// Its app-specific name keeps call sites distinct from system haptics APIs.
@MainActor
enum HapticFeedback {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
