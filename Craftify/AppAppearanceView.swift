//
//  AppAppearanceView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 14/05/2025.
//

import SwiftUI
import UIKit

private struct AppIcon: Identifiable {
    let id: String?        // nil = primary, otherwise CFBundleAlternateIcons key
    let name: String       // user-facing label
    let previewName: String// your normal Image set name
}

private struct AccentColorOption: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct AppAppearanceView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String?
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var errorMessage: String?
    @State private var supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons

    private let appIcons: [AppIcon] = [
        .init(id: nil,              name: "Craftify",     previewName: "AppIconPreview"),
        .init(id: "AlternateIcon1", name: "Craftify Grass", previewName: "AlternateIcon1Preview"),
        .init(id: "AlternateIcon2", name: "Craftify Grid", previewName: "AlternateIcon2Preview")
    ]

    private let accentColors: [AccentColorOption] = [
        .init(id: "default", name: "Default", color: .accentColor),
        .init(id: "green", name: "Green", color: Color(hex: "00AA00")),
        .init(id: "blue", name: "Blue", color: .blue),
        .init(id: "orange", name: "Orange", color: .orange),
        .init(id: "purple", name: "Purple", color: .purple)
    ]

    var body: some View {
        List {
            Section(header: Text("Appearance")) {
                Picker("Appearance", selection: $colorSchemePreference) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
                .accessibilityHint("Choose between System, Light, or Dark mode")
            }
            
            Section(header: Text("Accent Color")) {
                Picker("Accent Color", selection: $accentColorPreference) {
                    ForEach(accentColors) { option in
                        HStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 20, height: 20)
                            Text(option.name)
                        }
                        .tag(option.id)
                    }
                }
                .accessibilityLabel("Accent Color")
                .accessibilityHint("Choose the accent color for the app")
            }
            
            Section(header: Text("App Icons")) {
                if supportsAlternateIcons {
                    ForEach(appIcons) { icon in
                        Button {
                            changeIcon(to: icon.id)
                        } label: {
                            HStack(spacing: 12) {
                                if let uiImage = UIImage(named: icon.previewName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                }

                                Text(icon.name)
                                    .font(.headline)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                                if selectedAppIcon == icon.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .imageScale(.large)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        }
                        .accessibilityLabel("Select \(icon.name) icon")
                        .accessibilityHint(selectedAppIcon == icon.id ? "Currently selected" : "Double tap to select this icon")
                        .accessibilityAddTraits(.isButton)
                    }
                } else {
                    Text("Alternate icons aren’t available yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .accessibilityLabel("Alternate icons not available")
                        .accessibilityHint("Check back later for new icon options")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Appearance")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
        .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
        .alert("Error",
               isPresented: Binding(
                   get: { errorMessage != nil },
                   set: { if !$0 { errorMessage = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(errorMessage ?? "An unknown error occurred") }
        )
        .onAppear {
            selectedAppIcon = UIApplication.shared.alternateIconName
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
    }

    private func changeIcon(to iconName: String?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                if let err = error {
                    errorMessage = "Failed to change icon: \(err.localizedDescription)"
                } else {
                    selectedAppIcon = iconName
                    UIAccessibility.post(notification: .announcement, argument: "App icon changed to \(appIcons.first(where: { $0.id == iconName })?.name ?? "Default")")
                }
            }
        }
    }
}
