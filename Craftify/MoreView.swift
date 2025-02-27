//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    @EnvironmentObject var dataManager: DataManager
    @State private var isSyncing: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient Background
                LinearGradient(gradient: Gradient(colors: [
                    Color(hex: "00AA00").opacity(0.3),
                    Color(hex: "008800").opacity(0.8)
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                VStack(spacing: 16) {
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
                            Button(action: {
                                if let url = URL(string: "mailto:hello@davevancauwenberghe.be") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                listButton(title: "Report Missing Recipe", systemImage: "envelope.fill")
                            }
                            .listRowBackground(Color(uiColor: .tertiarySystemBackground))
                        }

                        // About Section
                        Section(header: Text("About").font(.headline)) {
                            NavigationLink(destination: AboutView()) {
                                listButton(title: "About Craftify", systemImage: "info.circle.fill")
                            }
                            .listRowBackground(Color(uiColor: .tertiarySystemBackground))
                        }

                        // Sync Status and Recipe Count Section
                        Section(header: Text("Data Management").font(.headline)) {
                            VStack(alignment: .center, spacing: 10) {
                                Text("\(dataManager.recipes.count) recipes available")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                Button(action: {
                                    isSyncing = true
                                    dataManager.loadData {
                                        dataManager.syncFavorites()
                                        isSyncing = false
                                    }
                                }) {
                                    actionButton(title: "Sync Recipes", systemImage: "arrow.clockwise", isLoading: $isSyncing)
                                }

                                Button(action: {
                                    dataManager.clearCache { success in
                                        print(success ? "Cache cleared successfully." : "Failed to clear cache.")
                                    }
                                }) {
                                    actionButton(title: "Clear Cache", systemImage: "trash.fill", color: .red)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("More")
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
    }

    // ✅ List button style (matches Data Management buttons)
    private func listButton(title: String, systemImage: String) -> some View {
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
    }

    // ✅ Action buttons (Sync & Clear Cache)
    private func actionButton(title: String, systemImage: String, isLoading: Binding<Bool>? = nil, color: Color = Color(hex: "00AA00")) -> some View {
        HStack {
            if let isLoading = isLoading?.wrappedValue, isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.trailing, 4)
            } else {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)
            }
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemBackground)) // Matches list row background
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient Background
                LinearGradient(gradient: Gradient(colors: [
                    Color(hex: "00AA00").opacity(0.3),
                    Color(hex: "008800").opacity(0.8)
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Craftify for Minecraft")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Version 1.0 - Build 27")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Release Notes Button
                    NavigationLink(destination: ReleaseNotesView()) {
                        buttonStyle(title: "Release Notes", systemImage: "doc.text.fill")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About Craftify")
            .navigationBarTitleDisplayMode(.inline)
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
}

struct ReleaseNotesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient Background
                LinearGradient(gradient: Gradient(colors: [
                    Color(hex: "00AA00").opacity(0.3),
                    Color(hex: "008800").opacity(0.8)
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Craftify for Minecraft")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Version 1.0 - Build 27")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Stay updated with the latest improvements, fixes, and new features added to Craftify.")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.top, 4)
                        }
                        .padding(.bottom, 8)
                    }
                    .listRowBackground(Color.clear)

                    // List of Release Notes
                    ForEach(releaseNotes, id: \.version) { note in
                        Section(header: Text(note.version).font(.headline).foregroundColor(.secondary)) {
                            ForEach(note.changes, id: \.self) { change in
                                Text("• \(change)")
                                    .padding(.vertical, 4)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Release Notes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ✅ Struct for Release Notes
struct ReleaseNote {
    let version: String
    let changes: [String]
}

// ✅ Updated Release Notes as a Data Array
let releaseNotes: [ReleaseNote] = [
    ReleaseNote(version: "Version 1.0 - Build 27", changes: [
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

