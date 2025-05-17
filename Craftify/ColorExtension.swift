//
//  ColorExtension.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 17/05/2025.
//

import SwiftUI

extension Color {
    static var userAccentColor: Color {
        let defaults = UserDefaults.standard
        let preference = defaults.string(forKey: "accentColorPreference") ?? "default"
        
        switch preference {
        case "green":
            return Color(hex: "00AA00")
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "default":
            fallthrough
        default:
            return .accentColor
        }
    }
}
