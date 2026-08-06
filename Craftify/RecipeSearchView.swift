//
//  RecipeSearchView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 15/05/2025.
//

import SwiftUI

struct RecipeSearchView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var filteredRecipes: [String: [Recipe]] = [:]
    @State private var navigationPath = NavigationPath()
    @State private var searchFilter: SearchFilter = .all

    enum SearchFilter: String, CaseIterable, Identifiable {
        case all = "Names & Ingredients"
        case names = "Recipe Names"
        case ingredients = "Ingredients"

        var id: Self { self }
        var symbol: String {
            switch self {
            case .all: "text.magnifyingglass"
            case .names: "character.cursor.ibeam"
            case .ingredients: "cube.fill"
            }
        }
    }

    private var recentSearchRecipes: [Recipe] {
        var resolved: [Recipe] = []
        for name in dataManager.recentSearchNames {
            if let recipe = dataManager.recipes.first(where: { $0.name == name }),
               !resolved.contains(where: { $0.id == recipe.id }) {
                resolved.append(recipe)
            }
        }
        return Array(resolved.prefix(10))
    }

    private var resultColumns: [GridItem] {
        CraftifyLayout.adaptiveColumns(
            minimum: dynamicTypeSize.isAccessibilitySize ? 300 : 320,
            maximum: 520,
            spacing: 14,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if searchText.isEmpty && !isSearchActive {
                        inactiveContent
                    } else if searchText.isEmpty {
                        searchState(
                            symbol: "text.cursor",
                            title: "Start Searching",
                            detail: "Enter a recipe name or an ingredient you already have."
                        )
                    } else if filteredRecipes.isEmpty {
                        searchState(
                            symbol: "magnifyingglass",
                            title: "No Recipes Found",
                            detail: "Try another term or change where Craftify searches."
                        )
                    } else {
                        resultsContent
                    }
                }
                .craftifyContentWidth()
                .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SearchFilter.allCases) { filter in
                            Button {
                                searchFilter = filter
                                updateFilteredRecipes()
                                HapticFeedback.selection()
                            } label: {
                                Label(filter.rawValue, systemImage: searchFilter == filter ? "checkmark" : filter.symbol)
                            }
                        }
                    } label: {
                        Label("Search Field", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Search in \(searchFilter.rawValue)")
                    .accessibilityHint("Changes which recipe fields Craftify searches")
                }
            }
            .overlay {
                if dataManager.isLoading && dataManager.recipes.isEmpty {
                    loadingState
                }
            }
            .craftifyPage()
            .onChange(of: isSearchActive) { _, active in
                if !active { searchText = "" }
            }
            .onChange(of: searchText) { _, _ in updateFilteredRecipes() }
            .onChange(of: dataManager.recipes) { _, _ in updateFilteredRecipes() }
            .onAppear {
                dataManager.syncChests()
                dataManager.syncRecentSearches()
                dataManager.fetchRecipes(isManual: false)
                updateFilteredRecipes()
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                    .onAppear {
                        dataManager.saveRecentSearch(recipe)
                        HapticFeedback.impact(.light)
                    }
            }
        }
    }

    private var inactiveContent: some View {
        Group {
            CraftifyHero(
                eyebrow: "Find Anything",
                title: "Search Your Recipe Book",
                detail: "Search by recipe name, ingredient, or both. Your recent finds follow you through iCloud.",
                symbol: "magnifyingglass"
            )

            if recentSearchRecipes.isEmpty {
                searchState(
                    symbol: "magnifyingglass.circle.fill",
                    title: "What Are You Crafting?",
                    detail: "Tap the search field and start with a recipe name or ingredient."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        CraftifySectionHeader(
                            title: "Recent Searches",
                            detail: "Quickly return to recipes you opened before."
                        )
                        Spacer(minLength: 12)
                        Button("Clear All") {
                            dataManager.clearRecentSearches()
                            HapticFeedback.impact(.medium)
                        }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHint("Removes all recent recipe searches")
                    }

                    RecentSearchesList(
                        recipes: recentSearchRecipes,
                        navigationPath: $navigationPath
                    )
                }
            }
        }
    }

    private var resultsContent: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Search Results")
                        .font(.title2.bold())
                    Text("Searching \(searchFilter.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CraftifyStatusPill(
                    title: "\(resultCount) found",
                    symbol: "magnifyingglass"
                )
            }

            ForEach(filteredRecipes.keys.sorted(), id: \.self) { letter in
                VStack(alignment: .leading, spacing: 10) {
                    Text(letter)
                        .font(.title2.bold())
                        .foregroundStyle(Color.userAccentColor)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: resultColumns, alignment: .leading, spacing: 12) {
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
    }

    private var resultCount: Int {
        filteredRecipes.values.reduce(0) { $0 + $1.count }
    }

    private func searchState(symbol: String, title: String, detail: String) -> some View {
        CraftifyEmptyState(symbol: symbol, title: title, detail: detail)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(Color.userAccentColor)
            Text("Loading Recipes…").font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppBackground().ignoresSafeArea() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading recipes")
    }

    private func updateFilteredRecipes() {
        let matches = searchText.isEmpty ? dataManager.recipes : dataManager.recipes.filter { recipe in
            switch searchFilter {
            case .all:
                recipe.name.localizedCaseInsensitiveContains(searchText)
                    || recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
            case .names:
                recipe.name.localizedCaseInsensitiveContains(searchText)
            case .ingredients:
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        filteredRecipes = Dictionary(grouping: matches) {
            String($0.name.prefix(1)).uppercased()
        }
        .mapValues { $0.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    }
}

struct RecentSearchItem: View {
    let recipe: Recipe
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 13) {
            CraftImage(key: recipe.image)
                .scaledToFit()
                .frame(width: 48, height: 48)
                .padding(5)
                .background(Color.userAccentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text(recipe.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 3)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .craftifyCard(cornerRadius: 17)
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.name), recent search")
        .accessibilityHint("Opens the crafting recipe")
    }
}

struct RecentSearchesList: View {
    let recipes: [Recipe]
    @Binding var navigationPath: NavigationPath
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        CraftifyLayout.adaptiveColumns(
            minimum: dynamicTypeSize.isAccessibilitySize ? 300 : 280,
            maximum: 420,
            spacing: 12,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(recipes) { recipe in
                NavigationLink(value: recipe) {
                    RecentSearchItem(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
