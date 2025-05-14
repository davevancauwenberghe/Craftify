//
//  AppIconsView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 14/05/2025.
//

import SwiftUI
import UIKit

private struct AppIcon: Identifiable {
    let id: String?        // nil = primary, otherwise CFBundleAlternateIcons key
    let name: String       // user‐facing label
    let previewName: String// your normal Image set name
}

struct AppIconsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String?
    @State private var errorMessage: String?
    @State private var supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons

    private let appIcons: [AppIcon] = [
        .init(id: nil,              name: "Craftify",     previewName: "AppIconPreview"),
        .init(id: "AlternateIcon1", name: "Craftify Grass", previewName: "AlternateIcon1Preview"),
        .init(id: "AlternateIcon2", name: "Craftify Grid", previewName: "AlternateIcon2Preview")
    ]

    var body: some View {
        List {
            Section {
                if supportsAlternateIcons {
                    ForEach(appIcons) { icon in
                        Button {
                            changeIcon(to: icon.id)
                        } label: {
                            HStack(spacing: 12) {
                                // Use your real preview image set:
                                if let uiImage = UIImage(named: icon.previewName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    // Should never happen if your preview sets exist
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                }

                                Text(icon.name)
                                    .font(.headline)
                                    .minimumScaleFactor(0.8) // Support Dynamic Type scaling
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
                        .minimumScaleFactor(0.8) // Support Dynamic Type scaling
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .accessibilityLabel("Alternate icons not available")
                        .accessibilityHint("Check back later for new icon options")
                }
            } header: {
                Text("App Icons")
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icons")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error",
               isPresented: Binding(
                   get: { errorMessage != nil },
                   set: { if !$0 { errorMessage = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(errorMessage ?? "An unknown error occurred") }
        )
        .onAppear {
            // Keep in sync if the user changed the icon elsewhere
            selectedAppIcon = UIApplication.shared.alternateIconName
        }
    }

    private func changeIcon(to iconName: String?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                if let err = error {
                    errorMessage = "Failed to change icon: \(err.localizedDescription)"
                } else {
                    selectedAppIcon = iconName
                    // Announce success to VoiceOver users
                    UIAccessibility.post(notification: .announcement, argument: "App icon changed to \(appIcons.first(where: { $0.id == iconName })?.name ?? "Default")")
                }
            }
        }
    }
}
