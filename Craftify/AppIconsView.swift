//
//  AppIconsView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 14/05/2025.
//

import SwiftUI
import UIKit

private struct AppIcon: Identifiable, Equatable {
    let id: String?         // `nil` for primary, string for alternate
    let name: String        // “Default”, “Alternate 1”, etc.
}

struct AppIconsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String?
    @State private var errorMessage: String?
    @State private var supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons

    private let appIcons: [AppIcon] = [
        .init(id: nil,              name: "Default"),
        .init(id: "AlternateIcon1", name: "Alternate 1"),
        .init(id: "AlternateIcon2", name: "Alternate 2")
    ]

    var body: some View {
        List {
            Section("App Icons") {
                if supportsAlternateIcons {
                    ForEach(appIcons) { icon in
                        Button {
                            changeIcon(to: icon.id)
                        } label: {
                            HStack(spacing: 12) {
                                // ← New: load the actual app-icon image
                                Image(uiImage: previewIcon(for: icon.id) ?? UIImage())
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(icon.name)
                                    .font(.headline)
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
                    }
                } else {
                    Text("Alternate app icons are not available yet. Check back soon!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .accessibilityLabel("Alternate icons unavailable")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icons")
        .navigationBarTitleDisplayMode(.large)
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(errorMessage ?? "") }
        )
        .onAppear {
            // Ensure we’re in sync if icon was changed elsewhere
            selectedAppIcon = UIApplication.shared.alternateIconName
        }
    }

    private func changeIcon(to iconName: String?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                if let err = error {
                    self.errorMessage = "Failed to change icon: \(err.localizedDescription)"
                } else {
                    self.selectedAppIcon = iconName
                }
            }
        }
    }

    private func previewIcon(for iconId: String?) -> UIImage? {
        guard let iconsDict = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any] else {
            return nil
        }

        // Decide primary vs. alternate
        if let id = iconId,
           let altIcons = iconsDict["CFBundleAlternateIcons"] as? [String: Any],
           let altSpec  = altIcons[id] as? [String: Any],
           let files    = altSpec["CFBundleIconFiles"] as? [String],
           let last     = files.last
        {
            return UIImage(named: last)
        }

        // Primary icon
        if let primary = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
           let files   = primary["CFBundleIconFiles"] as? [String],
           let last    = files.last
        {
            return UIImage(named: last)
        }

        return nil
    }
}
