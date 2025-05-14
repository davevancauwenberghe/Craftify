//
//  AppIconsView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 14/05/2025.
//

import SwiftUI
import UIKit

private struct AppIcon: Identifiable {
    let id: String?       // nil = default; otherwise the CFBundleAlternateIcons key
    let name: String      // user-facing label
    let previewName: String
}

struct AppIconsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String?
    @State private var errorMessage: String?
    @State private var supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons

    private let appIcons: [AppIcon] = [
        .init(id: nil,                name: "Default",      previewName: "AppIconPreview"),
        .init(id: "AlternateIcon1",   name: "Alternate 1",  previewName: "AlternateIcon1Preview"),
        .init(id: "AlternateIcon2",   name: "Alternate 2",  previewName: "AlternateIcon2Preview")
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
                                Image(icon.previewName)
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
                    Text("Alternate icons aren’t available yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                }
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
               message: { Text(errorMessage ?? "") }
        )
        .onAppear {
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
                }
            }
        }
    }
}

