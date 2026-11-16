//
//  ContentView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @SceneStorage("selectedTab") private var selectedTab = 0
    @State private var recipeLibraryResetID = UUID()

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            TabView(selection: $selectedTab) {
                Tab("Recipes", systemImage: "square.grid.2x2", value: 0) {
                    RecipesTabView(resetID: recipeLibraryResetID)
                }
                Tab("Chests", systemImage: "shippingbox.fill", value: 1) {
                    ChestsView()
                }
                Tab("More", systemImage: "ellipsis.circle", value: 2) {
                    MoreView()
                }
                Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search) {
                    RecipeSearchView()
                }
            }
            .tint(Color.userAccentColor(for: accentColorPreference))
            .preferredColorScheme(preferredColorScheme)

        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if dataManager.isManualSyncing {
                SyncStatusBanner()
            }
        }
        .sheet(item: announcementBinding) { announcement in
            NewRecipesOverlayView(recipes: announcement.recipes) {
                selectedTab = 0
                recipeLibraryResetID = UUID()
                dataManager.dismissNewRecipeAnnouncement()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: dataManager.isManualSyncing)
        .sensoryFeedback(.success, trigger: dataManager.newRecipeAnnouncement?.id)
        .onChange(of: selectedTab) { _, _ in
            HapticFeedback.selection()
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") { selectedTab = 0 }
            #endif
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private var announcementBinding: Binding<DataManager.NewRecipeAnnouncement?> {
        Binding(
            get: { dataManager.isManualSyncing ? nil : dataManager.newRecipeAnnouncement },
            set: { if $0 == nil { dataManager.dismissNewRecipeAnnouncement() } }
        )
    }
}
