//
//  ContentView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            TabView(selection: $selectedTab) {
                RecipesTabView(navigationPath: $navigationPath)
                    .tabItem { Label("Recipes", systemImage: "square.grid.2x2") }
                    .tag(0)
                    .accessibilityLabel("Recipes tab")
                    .accessibilityHint("Browse the Craftify recipe library")

                ChestsView()
                    .tabItem { Label("Chests", systemImage: "shippingbox.fill") }
                    .tag(1)
                    .accessibilityLabel("Chests tab")
                    .accessibilityHint("Organize recipes in synced chests")

                MoreView()
                    .tabItem { Label("More", systemImage: "ellipsis.circle") }
                    .tag(2)
                    .accessibilityLabel("More tab")
                    .accessibilityHint("Open Craftify tools, settings, and information")

                RecipeSearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(3)
                    .accessibilityLabel("Search tab")
                    .accessibilityHint("Search recipes by name or ingredient")
            }
            .tint(Color.userAccentColor(for: accentColorPreference))
            .preferredColorScheme(preferredColorScheme)

            if dataManager.isManualSyncing {
                SyncOverlayView(
                    horizontalSizeClass: horizontalSizeClass,
                    message: "Syncing Recipes…"
                )
                .transition(.opacity)
                .zIndex(2)
            }

            if !dataManager.isManualSyncing,
               let announcement = dataManager.newRecipeAnnouncement {
                NewRecipesOverlayView(
                    horizontalSizeClass: horizontalSizeClass,
                    recipes: announcement.recipes
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        dataManager.dismissNewRecipeAnnouncement()
                    }
                }
                .id(announcement.id)
                .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: dataManager.isManualSyncing)
        .sensoryFeedback(.success, trigger: dataManager.newRecipeAnnouncement?.id)
        .onChange(of: selectedTab) { _, newValue in
            HapticFeedback.selection()
            UIAccessibility.post(
                notification: .announcement,
                argument: "Selected tab: \(tabName(for: newValue))"
            )
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private func tabName(for tag: Int) -> String {
        switch tag {
        case 0: "Recipes"
        case 1: "Chests"
        case 2: "More"
        case 3: "Search"
        default: "Unknown"
        }
    }
}

struct RecipesTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Binding var navigationPath: NavigationPath

    var body: some View {
        NavigationStack(path: $navigationPath) {
            CategoryView()
                .navigationTitle("Craftify")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .overlay {
                    if dataManager.isLoading && dataManager.recipes.isEmpty {
                        loadingState
                    }
                }
                .navigationDestination(for: Recipe.self) { recipe in
                    RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                }
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            CraftifyAppMark(size: 72)
            ProgressView()
                .controlSize(.large)
                .tint(Color.userAccentColor)
                .accessibilityHidden(true)
            Text("Preparing Your Recipe Book")
                .font(.headline)
            Text("Loading recipes and crafting images…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppBackground().ignoresSafeArea() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing your recipe book. Loading recipes and crafting images.")
    }
}

struct CategoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("isCraftifyPicksExpanded") private var isCraftifyPicksExpanded = true
    @State private var selectedCategory: String?
    @State private var recommendedRecipes: [Recipe] = []
    @State private var filteredRecipes: [String: [Recipe]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            CategoryFilterBar(
                selectedCategory: $selectedCategory,
                categories: dataManager.categories
            )

            RecipeListView(
                recommendedRecipes: $recommendedRecipes,
                isCraftifyPicksExpanded: $isCraftifyPicksExpanded,
                filteredRecipes: filteredRecipes
            )
        }
        .background(alignment: .top) { AppHeroBackground(additionalHeight: 92) }
        .navigationTitle("Craftify")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshRecommendations()
            updateFilteredRecipes()
        }
        .onChange(of: dataManager.recipes) { _, _ in
            refreshRecommendations()
            updateFilteredRecipes()
        }
        .onChange(of: selectedCategory) { _, _ in updateFilteredRecipes() }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }

    private func refreshRecommendations() {
        recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(horizontalSizeClass == .regular ? 9 : 7))
    }

    private func updateFilteredRecipes() {
        let source = selectedCategory.map { category in
            dataManager.recipes.filter { $0.category == category }
        } ?? dataManager.recipes

        filteredRecipes = Dictionary(grouping: source) {
            String($0.name.prefix(1)).uppercased()
        }
        .mapValues { $0.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    }
}

struct CategoryFilterBar: View {
    @Binding var selectedCategory: String?
    let categories: [String]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "All", symbol: "square.grid.2x2", category: nil)
                ForEach(categories, id: \.self) { category in
                    filterButton(title: category, symbol: "cube.fill", category: category)
                }
            }
            .padding(7)
        }
        .craftifyFloatingSurface(cornerRadius: 18)
        .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
        .padding(.bottom, 8)
        .id(accentColorPreference)
        .accessibilityLabel("Recipe categories")
    }

    private func filterButton(title: String, symbol: String, category: String?) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
            HapticFeedback.selection()
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, horizontalSizeClass == .regular ? 15 : 12)
                .padding(.vertical, 9)
                .background(
                    isSelected ? Color.userAccentColor : Color.primary.opacity(0.055),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(title), selected" : title)
        .accessibilityHint("Filters the recipe library")
    }
}

struct AppHeroBackground: View {
    let additionalHeight: CGFloat?
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    init(additionalHeight: CGFloat? = 0) {
        self.additionalHeight = additionalHeight
    }

    var body: some View {
        GeometryReader { geometry in
            let navigationHeight = max(
                geometry.safeAreaInsets.top,
                max(geometry.frame(in: .global).minY, 0)
            )
            let height = additionalHeight.map { navigationHeight + $0 }
                ?? geometry.size.height + navigationHeight

            ZStack(alignment: .top) {
                AppBackground()
                LinearGradient(
                    colors: [
                        Color.userAccentColor(for: accentColorPreference).opacity(0.32),
                        Color.userAccentColor(for: accentColorPreference).opacity(0.10),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: height)
            }
        }
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }
}

struct RecipeListView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var recommendedRecipes: [Recipe]
    @Binding var isCraftifyPicksExpanded: Bool
    let filteredRecipes: [String: [Recipe]]

    private var recipeColumns: [GridItem] {
        if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return CraftifyLayout.adaptiveColumns(
            minimum: 320,
            maximum: 520,
            spacing: 16,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        Group {
            if dataManager.recipes.isEmpty {
                EmptyRecipeView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if !recommendedRecipes.isEmpty {
                            picksSection
                        }

                        ForEach(filteredRecipes.keys.sorted(), id: \.self) { letter in
                            recipeSection(letter)
                        }
                    }
                    .craftifyContentWidth()
                    .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { AppBackground().ignoresSafeArea() }
    }

    private var picksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                withAnimation(.snappy) { isCraftifyPicksExpanded.toggle() }
            }

            if isCraftifyPicksExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(recommendedRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeCell(recipe: recipe, isCraftifyPick: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func recipeSection(_ letter: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(letter)
                .font(.title2.bold())
                .foregroundStyle(Color.userAccentColor)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: recipeColumns, alignment: .leading, spacing: 12) {
                ForEach(filteredRecipes[letter] ?? []) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCell(recipe: recipe, isCraftifyPick: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct RecipeCell: View {
    let recipe: Recipe
    let isCraftifyPick: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if isCraftifyPick {
                pickContent
            } else {
                rowContent
            }
        }
        .craftifyCard(cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.name), \(recipe.category.isEmpty ? "recipe" : "\(recipe.category) recipe")")
        .accessibilityHint("Opens the crafting recipe")
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            recipeImage(size: dynamicTypeSize.isAccessibilitySize ? 72 : 62)

            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if !recipe.category.isEmpty {
                    Label(recipe.category, systemImage: "tag.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.userAccentColor)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
    }

    private var pickContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                AppBackground()
                recipeImage(size: horizontalSizeClass == .regular ? 96 : 82)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
                CraftifyStatusPill(title: "Pick", symbol: "sparkles")
                    .padding(9)
            }
            .frame(height: horizontalSizeClass == .regular ? 142 : 124)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text(recipe.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 280 : (horizontalSizeClass == .regular ? 220 : 188))
    }

    private func recipeImage(size: CGFloat) -> some View {
        CraftImage(key: recipe.image)
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(5)
            .background(Color.userAccentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct CraftifyPicksHeader: View {
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.userAccentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Craftify Picks")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("A fresh handful from the recipe book")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.userAccentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse Craftify Picks" : "Expand Craftify Picks")
        .accessibilityHint("Shows or hides recommended recipes")
    }
}
