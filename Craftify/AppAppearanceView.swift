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

private struct AccentColorOption: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct AppAppearanceView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String?
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @AppStorage("customDynamicTypeSize") private var customDynamicTypeSize: String = "large"
    @AppStorage("useCustomDynamicType") private var useCustomDynamicType: Bool = false
    @State private var errorMessage: String?
    @State private var supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12

    private var customDynamicType: DynamicTypeSize {
        get {
            switch customDynamicTypeSize {
            case "xSmall": return .xSmall
            case "small": return .small
            case "medium": return .medium
            case "large": return .large
            case "xLarge": return .xLarge
            case "xxLarge": return .xxLarge
            case "xxxLarge": return .xxxLarge
            case "accessibility1": return .accessibility1
            case "accessibility2": return .accessibility2
            case "accessibility3": return .accessibility3
            case "accessibility4": return .accessibility4
            case "accessibility5": return .accessibility5
            default: return .large
            }
        }
        set {
            switch newValue {
            case .xSmall: customDynamicTypeSize = "xSmall"
            case .small: customDynamicTypeSize = "small"
            case .medium: customDynamicTypeSize = "medium"
            case .large: customDynamicTypeSize = "large"
            case .xLarge: customDynamicTypeSize = "xLarge"
            case .xxLarge: customDynamicTypeSize = "xxLarge"
            case .xxxLarge: customDynamicTypeSize = "xxxLarge"
            case .accessibility1: customDynamicTypeSize = "accessibility1"
            case .accessibility2: customDynamicTypeSize = "accessibility2"
            case .accessibility3: customDynamicTypeSize = "accessibility3"
            case .accessibility4: customDynamicTypeSize = "accessibility4"
            case .accessibility5: customDynamicTypeSize = "accessibility5"
            @unknown default: customDynamicTypeSize = "large"
            }
        }
    }

    private let appIcons: [AppIcon] = [
        .init(id: nil, name: "Craftify", previewName: "AppIconPreview"),
        .init(id: "AlternateIcon1", name: "Craftify Grass", previewName: "AlternateIcon1Preview"),
        .init(id: "AlternateIcon2", name: "Craftify Grid", previewName: "AlternateIcon2Preview")
    ]

    private let accentColors: [AccentColorOption] = [
        .init(id: "default", name: "Default", color: Color(hex: "00AA00")),
        .init(id: "blue", name: "Blue", color: .blue),
        .init(id: "orange", name: "Orange", color: .orange),
        .init(id: "purple", name: "Purple", color: .purple),
        .init(id: "red", name: "Red", color: .red),
        .init(id: "teal", name: "Teal", color: .teal),
        .init(id: "pink", name: "Pink", color: .pink),
        .init(id: "yellow", name: "Yellow", color: .yellow)
    ]

    private let dynamicTypeSizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large,
        .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
    ]

    var body: some View {
        List {
            Section(header: Text("Appearance").font(.headline).minimumScaleFactor(0.6)) {
                Picker("Appearance", selection: $colorSchemePreference) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
                .accessibilityHint("Choose between System, Light, or Dark mode")
            }
            
            Section(header: Text("Accent Color").font(.headline).minimumScaleFactor(0.6)) {
                Picker("Accent Color", selection: $accentColorPreference) {
                    ForEach(accentColors) { option in
                        HStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: swatchSize, height: swatchSize)
                                .accessibilityLabel("\(option.name) color swatch")
                            Text(option.name)
                                .font(.body)
                                .minimumScaleFactor(0.6)
                        }
                        .tag(option.id)
                    }
                }
                .accessibilityLabel("Accent Color")
                .accessibilityHint("Choose the accent color for the app")
            }
            
            Section(header: Text("App Icons").font(.headline).minimumScaleFactor(0.6)) {
                if supportsAlternateIcons {
                    ForEach(appIcons) { icon in
                        Button {
                            changeIcon(to: icon.id)
                        } label: {
                            HStack(spacing: spacing) {
                                if let uiImage = UIImage(named: icon.previewName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: iconSize, height: iconSize)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: iconSize, height: iconSize)
                                }

                                Text(icon.name)
                                    .font(.headline)
                                    .minimumScaleFactor(0.6)
                                    .foregroundColor(Color.userAccentColor)
                                Spacer()
                                if selectedAppIcon == icon.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .imageScale(.large)
                                        .foregroundColor(Color.userAccentColor)
                                }
                            }
                            .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical)
                        }
                        .accessibilityLabel("Select \(icon.name) icon")
                        .accessibilityHint(selectedAppIcon == icon.id ? "Currently selected" : "Double tap to select this icon")
                        .accessibilityAddTraits(.isButton)
                    }
                } else {
                    Text("Alternate icons aren’t available yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.6)
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical)
                        .accessibilityLabel("Alternate icons not available")
                        .accessibilityHint("Check back later for new icon options")
                }
            }
            
            Section(header: Text("Text Size").font(.headline).minimumScaleFactor(0.6)) {
                Toggle("Custom Text Size", isOn: $useCustomDynamicType)
                    .font(.body)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Custom Text Size")
                    .accessibilityHint("Toggle to use a custom text size for the app instead of system settings")
                
                if useCustomDynamicType {
                    ScrollView {
                        Picker("Text Size", selection: $customDynamicTypeSize) {
                            ForEach(dynamicTypeSizes, id: \.self) { size in
                                Text(size.description)
                                    .font(.body)
                                    .minimumScaleFactor(0.6)
                                    .tag(size.id)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 300, height: 120)
                        .accessibilityLabel("Text Size Picker")
                        .accessibilityHint("Scroll to select a custom text size for the app")
                    }
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
        .onChange(of: dataManager.isLoading) { _, newValue in
            if !newValue && dataManager.isManualSyncing {
                // Placeholder for future DataManager dependencies
            }
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
        .dynamicTypeSize(useCustomDynamicType ? customDynamicType : dynamicTypeSize)
    }

    private func changeIcon(to: String?) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIApplication.shared.setAlternateIconName(to) { error in
            DispatchQueue.main.async {
                if let err = error {
                    errorMessage = "Failed to change icon: \(err.localizedDescription)"
                } else {
                    selectedAppIcon = to
                    UIAccessibility.post(notification: .announcement, argument: "App icon changed to \(appIcons.first(where: { $0.id == to })?.name ?? "Default")")
                }
            }
        }
    }
}

extension DynamicTypeSize {
    var id: String {
        switch self {
        case .xSmall: return "xSmall"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "large"
        case .xLarge: return "xLarge"
        case .xxLarge: return "xxLarge"
        case .xxxLarge: return "xxxLarge"
        case .accessibility1: return "accessibility1"
        case .accessibility2: return "accessibility2"
        case .accessibility3: return "accessibility3"
        case .accessibility4: return "accessibility4"
        case .accessibility5: return "accessibility5"
        @unknown default: return "large"
        }
    }

    var description: String {
        switch self {
        case .xSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xLarge: return "Extra Large"
        case .xxLarge: return "Extra Extra Large"
        case .xxxLarge: return "Extra Extra Extra Large"
        case .accessibility1: return "Accessibility 1"
        case .accessibility2: return "Accessibility 2"
        case .accessibility3: return "Accessibility 3"
        case .accessibility4: return "Accessibility 4"
        case .accessibility5: return "Accessibility 5"
        @unknown default: return "Large"
        }
    }
}
