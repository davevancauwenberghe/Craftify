//
//  AppAppearanceView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 14/05/2025.
//

import SwiftUI
import UIKit

private struct AppIcon: Identifiable {
    let id: String?
    let name: String
    let previewName: String
}

struct AccentColorOption: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct AppAppearanceView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String?
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    @State private var errorMessage: String?
    @State private var supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons
    @State private var isChangingIcon = false

    private let appIcons: [AppIcon] = [
        .init(id: nil, name: "Craftify", previewName: "AppIconPreview"),
        .init(id: "AlternateIcon1", name: "Craftify Grass", previewName: "AlternateIcon1Preview"),
        .init(id: "AlternateIcon2", name: "Craftify Grid", previewName: "AlternateIcon2Preview"),
        .init(id: "AlternateIcon3", name: "Craftify Beta", previewName: "AlternateIcon3Preview")
    ]

    static let accentColors: [AccentColorOption] = [
        .init(id: "default", name: "Default", color: Color(hex: "00AA00")),
        .init(id: "blue", name: "Blue", color: .blue),
        .init(id: "orange", name: "Orange", color: .orange),
        .init(id: "purple", name: "Purple", color: .purple),
        .init(id: "red", name: "Red", color: .red),
        .init(id: "teal", name: "Teal", color: .teal),
        .init(id: "pink", name: "Pink", color: .pink),
        .init(id: "yellow", name: "Yellow", color: .yellow),
        .init(id: "indigo", name: "Indigo", color: .indigo),
        .init(id: "forest", name: "Forest", color: Color(hex: "287A3D")),
        .init(id: "brown", name: "Brown", color: .brown),
        .init(id: "slate", name: "Slate", color: Color(hex: "607D8B"))
    ]

    private var selectedAccentColor: Color {
        Self.accentColors.first { $0.id == accentColorPreference }?.color
            ?? Self.accentColors[0].color
    }

    private var accentColumns: [GridItem] {
        CraftifyLayout.adaptiveColumns(
            minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 128,
            maximum: 220,
            spacing: 10,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private var iconColumns: [GridItem] {
        CraftifyLayout.adaptiveColumns(
            minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 190,
            maximum: 280,
            spacing: 14,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                CraftifyHero(
                    eyebrow: "Your Craftify",
                    title: "Make It Feel Like Yours",
                    detail: "Choose an appearance, accent, and app icon. Every option keeps the same accessible Craftify experience.",
                    symbol: "paintpalette.fill"
                )

                appearanceSection
                accentSection
                appIconSection
            }
            .craftifyContentWidth(CraftifyLayout.formMaxWidth)
            .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("App Appearance")
        .navigationBarTitleDisplayMode(.large)
        .craftifyPage()
        .alert("Couldn’t Change App Icon", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .onAppear { selectedAppIcon = UIApplication.shared.alternateIconName }
        .preferredColorScheme(preferredColorScheme)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            CraftifySectionHeader(
                title: "Appearance",
                detail: "Follow the device or choose a permanent light or dark canvas.",
                symbol: "circle.lefthalf.filled"
            )

            Picker("Appearance", selection: $colorSchemePreference) {
                Label("System", systemImage: "iphone").tag("system")
                Label("Light", systemImage: "sun.max.fill").tag("light")
                Label("Dark", systemImage: "moon.fill").tag("dark")
            }
            .pickerStyle(.segmented)
            .onChange(of: colorSchemePreference) { _, _ in HapticFeedback.selection() }
            .accessibilityHint("Choose System, Light, or Dark appearance")
        }
        .padding(18)
        .craftifyCard(cornerRadius: 22)
    }

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            CraftifySectionHeader(
                title: "Accent Color",
                detail: "Your selection colors controls, crafting highlights, and the Craftify atmosphere.",
                symbol: "paintbrush.pointed.fill"
            )

            LazyVGrid(columns: accentColumns, spacing: 10) {
                ForEach(Self.accentColors) { option in
                    accentButton(option)
                }
            }
        }
        .padding(18)
        .craftifyCard(cornerRadius: 22)
    }

    private func accentButton(_ option: AccentColorOption) -> some View {
        let isSelected = accentColorPreference == option.id

        return Button {
            accentColorPreference = option.id
            HapticFeedback.selection()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(option.color.gradient)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
                Text(option.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(option.color)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(
                option.color.opacity(isSelected ? 0.14 : 0.045),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(option.color.opacity(isSelected ? 0.60 : 0.15), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            CraftifySectionHeader(
                title: "App Icon",
                detail: "Pick the Craftify mark you want to see on your Home Screen.",
                symbol: "app.fill"
            )

            if supportsAlternateIcons {
                LazyVGrid(columns: iconColumns, spacing: 14) {
                    ForEach(appIcons) { icon in
                        appIconButton(icon)
                    }
                }
            } else {
                Label("Alternate icons aren’t available on this device.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(18)
        .craftifyCard(cornerRadius: 22)
    }

    private func appIconButton(_ icon: AppIcon) -> some View {
        let isSelected = selectedAppIcon == icon.id

        return Button {
            changeIcon(to: icon.id)
        } label: {
            HStack(spacing: 14) {
                Group {
                    if let image = UIImage(named: icon.previewName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "app.dashed")
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(icon.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(isSelected ? "Current icon" : "Tap to select")
                        .font(.caption)
                        .foregroundStyle(isSelected ? selectedAccentColor : Color.secondary)
                }
                Spacer(minLength: 3)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? selectedAccentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(
                selectedAccentColor.opacity(isSelected ? 0.10 : 0.03),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(selectedAccentColor.opacity(isSelected ? 0.48 : 0.12), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isChangingIcon || isSelected)
        .accessibilityLabel(icon.name)
        .accessibilityValue(isSelected ? "Current icon" : "Not selected")
        .accessibilityHint(isSelected ? "" : "Changes Craftify’s Home Screen icon")
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func changeIcon(to name: String?) {
        guard !isChangingIcon, UIApplication.shared.alternateIconName != name else { return }
        isChangingIcon = true
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                isChangingIcon = false
                if let error {
                    HapticFeedback.notification(.error)
                    errorMessage = error.localizedDescription
                } else {
                    HapticFeedback.notification(.success)
                    selectedAppIcon = name
                    let displayName = appIcons.first(where: { $0.id == name })?.name ?? "Craftify"
                    UIAccessibility.post(notification: .announcement, argument: "App icon changed to \(displayName)")
                }
            }
        }
    }
}
