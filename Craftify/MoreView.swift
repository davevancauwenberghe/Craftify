//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct MoreView: View {
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private func formatSyncDate(_ date: Date?) -> String {
        guard let date = date else { return "Not synced" }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Synced: \(formatter.string(from: date))"
    }
    
    var body: some View {
        NavigationStack {
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
                
                Section(header: Text("Need Help?")) {
                    NavigationLink(destination: ReportMissingRecipeView()) {
                        buttonStyle(title: "Report missing recipe", systemImage: "envelope.fill")
                    }
                    .accessibilityLabel("Report missing recipe")
                    .accessibilityHint("Navigate to report a missing recipe")
                }
                
                Section(header: Text("About")) {
                    NavigationLink(destination: AboutView()) {
                        buttonStyle(title: "About Craftify", systemImage: "info.circle.fill")
                    }
                    .accessibilityLabel("About Craftify")
                    .accessibilityHint("View information about the Craftify app")
                    
                    Text("Craftify for Minecraft is not an official Minecraft product, it is not approved or associated with Mojang or Microsoft.")
                        .font(horizontalSizeClass == .regular ? .callout : .footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .accessibilityLabel("Disclaimer")
                        .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")
                }
                
                Section(header: Text("Data Management")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(dataManager.recipes.count) recipes available")
                                .accessibilityLabel("Recipe Count")
                                .accessibilityHint("\(dataManager.recipes.count) Minecraft recipes are available")
                            Text(dataManager.lastUpdated != nil ? formatSyncDate(dataManager.lastUpdated) : dataManager.syncStatus)
                                .accessibilityLabel("Sync Status")
                                .accessibilityHint(dataManager.syncStatus)
                        }
                        .font(horizontalSizeClass == .regular ? .callout : .footnote)
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        
                        Button(action: {
                            print("Sync Recipes tapped")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.loadData(isManual: true) {
                                dataManager.syncFavorites()
                                print("Sync Recipes completed")
                            }
                        }) {
                            HStack {
                                if dataManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .padding(.trailing, 8)
                                        .accessibilityLabel("Syncing")
                                        .accessibilityHint("Recipes are currently syncing")
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title2)
                                        .foregroundColor(Color(hex: "00AA00"))
                                }
                                Text("Sync Recipes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(horizontalSizeClass == .regular ? 16 : 12)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .disabled(dataManager.isLoading)
                        .accessibilityLabel("Sync Recipes")
                        .accessibilityHint("Syncs Minecraft recipes from CloudKit")
                        
                        Button(action: {
                            print("Clear Cache tapped")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.clearCache { success in
                                if !success {
                                    dataManager.errorMessage = "Failed to clear cache. Please try again."
                                }
                                print("Clear Cache completed, success: \(success)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Clear Cache")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(horizontalSizeClass == .regular ? 16 : 12)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Clear Cache")
                        .accessibilityHint("Clears the cached Minecraft recipes")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
            .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
            .alert(isPresented: Binding(
                get: { dataManager.errorMessage != nil },
                set: { if !$0 { dataManager.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(dataManager.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .preferredColorScheme(
                colorSchemePreference == "system" ? nil :
                (colorSchemePreference == "light" ? .light : .dark)
            )
        }
    }
    
    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(Color(hex: "00AA00"))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
    }
}

struct AboutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) – Build \(build)"
    }

    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
            VStack(spacing: 8) {
                Image(uiImage: UIImage(named: "AppIconPreview") ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 2, x: 0, y: 1)
                    .accessibilityLabel("Craftify app icon")
                    .accessibilityAddTraits(.isImage)

                Text("Craftify for Minecraft")
                    .font(horizontalSizeClass == .regular ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
            }
            .padding(.top, horizontalSizeClass == .regular ? 16 : 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Craftify for Minecraft, \(appVersion). Craftify helps you manage your recipes and favorites.")
            .accessibilityHint("About the Craftify app and its purpose")

            List {
                Section {
                    NavigationLink(destination: AppIconsView()) {
                        buttonStyle(title: "App Icons", systemImage: "app.badge.fill")
                    }
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    )
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top:    horizontalSizeClass == .regular ? 12 : 8,
                        leading:horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing:horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("App Icons")
                    .accessibilityHint("Choose an alternate app icon for Craftify")

                    NavigationLink(destination: ReleaseNotesView()) {
                        buttonStyle(title: "Release Notes", systemImage: "doc.text.fill")
                    }
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    )
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top:    horizontalSizeClass == .regular ? 12 : 8,
                        leading:horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing:horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("Release Notes")
                    .accessibilityHint("View the release notes for Craftify")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .scrollDisabled(true)
            .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let supportEmail = "hello@davevancauwenberghe.be"
                if let url = URL(string: "mailto:\(supportEmail)") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Contact Support")
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 24)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 600 : 400)
            .padding(.bottom, 8)
            .accessibilityLabel("Contact Support")
            .accessibilityHint("Opens the mail app to contact support")

            Text("Craftify for Minecraft is not an official Minecraft product; it is not approved or associated with Mojang or Microsoft.")
                .font(horizontalSizeClass == .regular ? .callout : .footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                .accessibilityLabel("Disclaimer")
                .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")

            Spacer()
        }
        .padding(horizontalSizeClass == .regular ? 12 : 8)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .safeAreaInset(edge: .top)    { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).prepare()
        }
    }

    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(Color(hex: "00AA00"))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
    }
}

struct ReleaseNotesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "33"
        return "Version \(version) - Build \(build)"
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 12 : 8) {
                    Text("Craftify for Minecraft")
                        .font(horizontalSizeClass == .regular ? .title : .largeTitle)
                        .fontWeight(.bold)
                    
                    Text(appVersion)
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .foregroundColor(.secondary)
                    
                    Text("Stay updated with the latest improvements, fixes, and new features added to Craftify.")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
                .padding(.bottom, horizontalSizeClass == .regular ? 12 : 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Craftify for Minecraft, \(appVersion). Stay updated with the latest improvements, fixes, and new features added to Craftify.")
                .accessibilityHint("Release notes overview")
            }
            .listRowBackground(Color(UIColor.systemBackground))
            
            ForEach(releaseNotes, id: \.version) { note in
                Section(header: Text(note.version)
                            .font(.headline)
                            .foregroundColor(.secondary)) {
                    ForEach(note.changes, id: \.self) { change in
                        Text("• \(change)")
                            .font(horizontalSizeClass == .regular ? .subheadline : .footnote)
                            .foregroundColor(.primary)
                            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                            .accessibilityLabel(change)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Release Notes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
        .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
    }
}

struct ReleaseNote {
    let version: String
    let changes: [String]
}

let releaseNotes: [ReleaseNote] = [
    ReleaseNote(version: "Version 1.0 - Build 54-57", changes: [
        "Improved search",
        "Onboarding added",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 47-53", changes: [
        "Alternate app icons added",
        "SwiftUI optimalisations",
        "Clipping views fixed on iPad",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 41-46", changes: [
        "Reworked Recipes & Favorites view",
        "Search bar randomly collapsing fixed",
        "VoiceOver improvements",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 38-40", changes: [
        "Adaptive grid view",
        "Remarks added into the popup when needed",
        "Updated search bar in the main view",
        "Image assets added",
        "UI fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 35-37", changes: [
        "RecipeDetailView reworked (New detail view implemented when tapping cells)",
        "Ingredient and output popup updated",
        "Category label updated",
        "Alternate crafting options added",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 34", changes: [
        "MoreView reworked",
        "AboutView reworked",
        "DataManager optimalisation",
        "Improved CloudKit integration",
        "VoiceOver improvements"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 29-33", changes: [
        "UI streamlining",
        "Image assets added",
        "Craftify Picks added to scrollview",
        "Reporting missing recipes now uses a form instead of opening mail",
        "Bug fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 25-28", changes: [
        "Data Manager fetches more than 100 recipes",
        "Implemented a test UI update in More",
        "Updated release notes view",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 24", changes: [
        "Added: RecipeDetailView now shows more info regarding which utility block needs to be used",
        "CloudKit Container expanded with new strings for optional remarks",
        "Added: Image assets",
        "Asynchronous loading"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 22-23", changes: [
        "Added: Search on Categories",
        "Added: Basic LaunchScreen"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 21", changes: [
        "Added: Collapsible Craftify Picks",
        "Added: Image assets",
        "Removed: Share button in the RecipeDetailView"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 20", changes: [
        "Updated Favorites when no favorites are added yet",
        "Updated Image assets naming"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 14-19", changes: [
        "Added: Data management in More",
        "Added: Image Assets",
        "UI fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 11-13", changes: [
        "CloudKit support added",
        "Added: Local cache",
        "Added: Sync info in More"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 1-10", changes: [
        "Initial release of Craftify for Minecraft.",
        "Recipe management and favorite syncing via CloudKit.",
        "Improved UI for crafting grid and recipe details.",
        "Enhanced haptic feedback and smooth transitions."
    ])
]
