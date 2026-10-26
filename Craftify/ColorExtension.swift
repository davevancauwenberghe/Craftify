//
//  ColorExtension.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 17/05/2025.
//

import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
    
    static var userAccentColor: Color {
        let defaults = UserDefaults.standard
        let preference = defaults.string(forKey: "accentColorPreference") ?? "default"

        return userAccentColor(for: preference)
    }

    /// Resolves an accent directly from the observed preference. This avoids a
    /// second UserDefaults read when a view is already driven by `@AppStorage`.
    static func userAccentColor(for preference: String) -> Color {
        switch preference {
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "red":
            return .red
        case "teal":
            return .teal
        case "pink":
            return .pink
        case "yellow":
            return .yellow
        case "indigo":
            return .indigo
        case "forest":
            return Color(hex: "287A3D")
        case "brown":
            return .brown
        case "slate":
            return Color(hex: "607D8B")
        case "default":
            fallthrough
        default:
            return Color(uiColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 0, green: 170 / 255.0, blue: 0, alpha: 1)
                }
                return UIColor(red: 22 / 255.0, green: 130 / 255.0, blue: 56 / 255.0, alpha: 1)
            })
        }
    }
}
