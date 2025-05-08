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
    @State private var isSyncing: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
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

                // Need Help Section
                Section(header: Text("Need Help?")) {
                    NavigationLink(destination: ReportMissingRecipeView()) {
                        buttonStyle(title: "Report Missing Recipe", systemImage: "envelope.fill")
                    }
                    .accessibilityLabel("Report Missing Recipe")
                    .accessibilityHint("Navigate to report a missing recipe")
                }

                // About Section
                Section(header: Text("About")) {
                    NavigationLink(destination: AboutView()) {
                        buttonStyle(title: "About Craftify", systemImage: "info.circle.fill")
                    }
                    .accessibilityLabel("About Craftify")
                    .accessibilityHint("View information about the Craftify app")
                    
                    Text("Craftify for Minecraft is not an official Minecraft product, it is not approved or associated with Mojang or Microsoft.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .accessibilityLabel("Disclaimer")
                        .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")
                }

                // Data Management Section
                Section(header: Text("Data Management")) {
                    VStack(alignment: .center, spacing: 10) {
                        Text("\(dataManager.recipes.count) recipes available")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Recipe Count")
                            .accessibilityHint("\(dataManager.recipes.count) Minecraft recipes are available")

                        Text(dataManager.syncStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Sync Status")
                            .accessibilityHint(dataManager.syncStatus)

                        // Sync Recipes Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isSyncing = true
                            dataManager.loadData {
                                dataManager.syncFavorites()
                                isSyncing = false
                            }
                        }) {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .padding(.trailing, 4)
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
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(10)
                        }
                        .disabled(isSyncing)
                        .accessibilityLabel("Sync Recipes")
                        .accessibilityHint("Syncs Minecraft recipes from CloudKit")

                        // Clear Cache Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.clearCache { success in
                                if !success {
                                    errorMessage = "Failed to clear cache. Please try again."
                                    showErrorAlert = true
                                }
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
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(10)
                        }
                        .accessibilityLabel("Clear Cache")
                        .accessibilityHint("Clears the cached Minecraft recipes")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .preferredColorScheme(
                colorSchemePreference == "system" ? nil :
                (colorSchemePreference == "light" ? .light : .dark)
            )
        }
    }

    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(Color(hex: "00AA00"))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Fetch version and build number dynamically from Bundle
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "33"
        return "Version \(version) - Build \(build)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // App Info
                VStack(spacing: 8) {
                    Text("Craftify for Minecraft")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Craftify for Minecraft, \(appVersion). Craftify helps you manage your recipes and favorites.")
                .accessibilityHint("About the Craftify app and its purpose")

                // Release Notes Button
                NavigationLink(destination: ReleaseNotesView()) {
                    buttonStyle(title: "Release Notes", systemImage: "doc.text.fill")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                })
                .accessibilityLabel("Release Notes")
                .accessibilityHint("View the release notes for Craftify")

                // Contact Support Button
                Link(destination: URL(string: "mailto:hello@davevancauwenberghe.be")!) {
                    buttonStyle(title: "Contact Support", systemImage: "envelope.fill")
                }
                .accessibilityLabel("Contact Support")
                .accessibilityHint("Opens the mail app to contact support at hello@davevancauwenberghe.be")

                // Disclaimer
                Text("Craftify for Minecraft is not an official Minecraft product, it is not approved or associated with Mojang or Microsoft.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityLabel("Disclaimer")
                    .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("About Craftify")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Preload haptics for smoother feedback
                UIImpactFeedbackGenerator(style: .medium).prepare()
            }
        }
    }

    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(Color(hex: "00AA00"))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(
            Color(UIColor.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(
                    color: colorScheme == .light ? .black.opacity(0.15) : .black.opacity(0.3),
                    radius: colorScheme == .light ? 6 : 8
                )
        )
    }
}

struct ReleaseNotesView: View {
    // Fetch version and build number dynamically from Bundle
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "33"
        return "Version \(version) - Build \(build)"
    }

    var body: some View {
        List {
            // Header Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Craftify for Minecraft")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(appVersion)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Stay updated with the latest improvements, fixes, and new features added to Craftify.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
            // Preserve default system background
            .listRowBackground(Color(UIColor.systemBackground))

            // Release Notes Sections
            ForEach(releaseNotes, id: \.version) { note in
                Section(header: Text(note.version)
                            .font(.headline)
                            .foregroundColor(.secondary)) {
                    ForEach(note.changes, id: \.self) { change in
                        Text("• \(change)")
                            .padding(.vertical, 4)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Release Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReleaseNote {
    let version: String
    let changes: [String]
}

let releaseNotes: [ReleaseNote] = [
    ReleaseNote(version: "Version 1.0 - Build 41", changes: [
        "UI fixes on iPad"
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
    ReleaseNote(version: "Version 1.0 - Build 31-33", changes: [
        "UI streamlining",
        "Image assets added",
        "Bug fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 30", changes: [
        "UI fixes",
        "Bug fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 29", changes: [
        "Craftify Picks added to scrollview",
        "Reporting missing recipes now uses a form instead of opening mail"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 27-28", changes: [
        "Data Manager fetches more than 100 recipes now",
        "Implemented a test UI update in More",
        "Updated release notes view"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 25-26", changes: [
        "Added: Image Assets"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 24", changes: [
        "Added: RecipeDetailView now shows more info regarding which utility block needs to be used",
        "CloudKit Container expanded with new strings for optional remarks",
        "Added: Image assets",
        "Asynchronous loading"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 22-23", changes: [
        "MacOS Native Support test",
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
    ReleaseNote(version: "Version 1.0 - Build 13", changes: [
        "Added: Pull to refresh",
        "Added: Local cache",
        "Added: Sync info in More"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 12", changes: [
        "CloudKit update"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 11", changes: [
        "CloudKit support added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 1-10", changes: [
        "Initial release of Craftify for Minecraft.",
        "Recipe management and favorite syncing via CloudKit.",
        "Improved UI for crafting grid and recipe details.",
        "Enhanced haptic feedback and smooth transitions."
    ])
]
