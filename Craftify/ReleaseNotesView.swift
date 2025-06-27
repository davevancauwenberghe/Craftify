//
//  ReleaseNotesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 17/05/2025.
//

import SwiftUI

struct ReleaseNotesView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    
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
                        .foregroundColor(Color.userAccentColor)
                    
                    Text("Stay updated with the latest improvements, fixes, and new features added to Craftify.")
                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
                .padding(.bottom, horizontalSizeClass == .regular ? 12 : 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Craftify for Minecraft")
                .accessibilityValue("\(appVersion). Stay updated with the latest improvements, fixes, and new features.")
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
        .id(accentColorPreference)
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
    ReleaseNote(version: "Version 1.0 - Build 90", changes: [
        "Tab bar on iOS/iPadOS 17 fixed",
        "Search icon on iPadOS 18 instead of label"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 76-89", changes: [
        "Extensive Swift code rewriting and refactoring",
        "Privacy policy URL button added",
        "VoiceOver enhancements",
        "UX improvements",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 61-75", changes: [
        "Major report recipes issues improvements",
        "Privacy policy & data control added",
        "Network status added",
        "Image assets added",
        "UI fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 58-60", changes: [
        "Accent themes added",
        "Onboarding moved to the main app entry",
        "Code sequence updates",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 54-57", changes: [
        "Improved search",
        "Onboarding added",
        "Image assets added"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 47-53", changes: [
        "Alternate app icons added",
        "SwiftUI optimisations",
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
        "DataManager optimisation",
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
        "Image assets added",
        "Asynchronous loading"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 20-23", changes: [
        "Added: Search on Categories",
        "Added: Basic LaunchScreen",
        "Added: Collapsible Craftify Picks",
        "Image assets added",
        "Removed: Share button in the RecipeDetailView",
        "Updated Favorites when no favorites are added yet",
        "Updated Image assets naming"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 14-19", changes: [
        "Added: Data management in More",
        "Image assets added",
        "UI fixes"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 11-13", changes: [
        "CloudKit support added",
        "Local cache added",
        "Sync info added in More"
    ]),
    ReleaseNote(version: "Version 1.0 - Build 1-10", changes: [
        "Initial build of Craftify for Minecraft.",
        "Recipe management and favorite syncing via CloudKit.",
        "Improved UI for crafting grid and recipe details.",
        "Enhanced haptic feedback and smooth transitions."
    ])
]
