//
//  ColorExtension.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 17/05/2025.
//

import SwiftUI

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
        // Note: This reads from UserDefaults, which is kept in sync with DataManager.accentColorPreference
        // by AppAppearanceView when syncAccentColor is enabled. When syncAccentColor is disabled,
        // UserDefaults reflects the local device preference.
        let defaults = UserDefaults.standard
        let preference = defaults.string(forKey: "accentColorPreference") ?? "default"
        
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
        case "default":
            fallthrough
        default:
            return Color(hex: "00AA00")
        }
    }
}
