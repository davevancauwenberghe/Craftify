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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section(header: Text("Appearance").font(.headline)) {
                    Picker("Appearance", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // "Need help?" Section
                Section(header: Text("Need help?").font(.headline)) {
                    NavigationLink(destination: ReportMissingRecipeView()) {
                        buttonStyle(title: "Report missing recipe", systemImage: "envelope.fill")
                    }
                }

                // About Section
                Section(header: Text("About").font(.headline)) {
                    NavigationLink(destination: AboutView()) {
                        buttonStyle(title: "About Craftify", systemImage: "info.circle.fill")
                    }
                }

                // Sync Status and Recipe Count Section
                Section(header: Text("Data Management").font(.headline)) {
                    VStack(alignment: .center, spacing: 10) {
                        Text("\(dataManager.recipes.count) recipes available")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

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
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title2)
                                        .foregroundColor(Color(hex: "00AA00"))
                                }
                                Text("Sync recipes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(10)
                        }

                        // Clear Cache Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.clearCache { success in }
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
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
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
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Craftify for Minecraft")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Version 1.0 - Build 31")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // Inline-styled Release Notes button.
                NavigationLink(destination: ReleaseNotesView()) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                        Text("Release Notes")
                            .font(.title3)
                            .bold()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("About Craftify")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// Standard button style (same as MoreView)
private func buttonStyle(title: String, systemImage: String) -> some View {
    HStack {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundColor(Color(hex: "00AA00"))
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color(uiColor: .secondarySystemBackground))
    .cornerRadius(10)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
}

struct ReleaseNotesView: View {
    var body: some View {
        NavigationStack {
            List {
                // Header Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Craftify for Minecraft")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Version 1.0 - Build 31")
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
}

struct ReleaseNote {
    let version: String
    let changes: [String]
}

let releaseNotes: [ReleaseNote] = [
    ReleaseNote(version: "Version 1.0 - Build 31", changes: [
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
