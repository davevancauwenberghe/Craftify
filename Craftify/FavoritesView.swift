//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import UIKit

struct EmptyFavoritesView: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 16

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: "heart.slash")
                .font(.system(size: iconSize))
                .foregroundStyle(.secondary)

            Text("No favorite recipes")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text(
                """
                You haven't added any favorite recipes yet.
                Explore recipes and tap the heart to mark them as favorites.
                """
            )
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, padding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(padding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            """
            No favorite recipes. You haven't added any favorite recipes yet. \
            Explore recipes and tap the heart to mark them as favorites.
            """
        )
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct FavoritesSection: View {
    let filteredFavorites: [String: [Recipe]]
    let navigationPath: Binding<NavigationPath>
    let horizontalSizeClass: UserInterfaceSizeClass?

    @ScaledMetric(relativeTo: .body) private var gridSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8

    var body: some View {
        ForEach(filteredFavorites.keys.sorted(), id: \.self) { letter in
            Section {
                if horizontalSizeClass == .regular {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: gridSpacing),
                            GridItem(.flexible(), spacing: gridSpacing)
                        ],
                        alignment: .leading,
                        spacing: gridSpacing
                    ) {
                        ForEach(
                            filteredFavorites[letter] ?? [],
                            id: \.name
                        ) { recipe in
                            NavigationLink {
                                RecipeDetailView(
                                    recipe: recipe,
                                    navigationPath: navigationPath
                                )
                            } label: {
                                RecipeCell(
                                    recipe: recipe,
                                    isCraftifyPick: false
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, paddingHorizontal * 1.5)
                } else {
                    ForEach(
                        filteredFavorites[letter] ?? [],
                        id: \.name
                    ) { recipe in
                        NavigationLink {
                            RecipeDetailView(
                                recipe: recipe,
                                navigationPath: navigationPath
                            )
                        } label: {
                            RecipeCell(
                                recipe: recipe,
                                isCraftifyPick: false
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            } header: {
                Text(letter)
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(
                        .horizontal,
                        horizontalSizeClass == .regular
                            ? paddingHorizontal * 1.5
                            : paddingHorizontal
                    )
                    .padding(.vertical, paddingVertical)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("accentColorPreference")
    private var accentColorPreference = "default"

    @State private var navigationPath = NavigationPath()
    @State private var recommendedRecipes: [Recipe] = []
    @State private var selectedCategory: String?
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredFavorites: [String: [Recipe]] = [:]

    @ScaledMetric(relativeTo: .body)
    private var buttonPaddingHorizontal: CGFloat = 16

    @ScaledMetric(relativeTo: .body)
    private var buttonPaddingVertical: CGFloat = 8

    @ScaledMetric(relativeTo: .body)
    private var hStackSpacing: CGFloat = 8

    private var favoriteCategories: [String] {
        Array(
            Set(
                dataManager.favorites.compactMap {
                    $0.category.isEmpty ? nil : $0.category
                }
            )
        )
        .sorted()
    }

    private func updateFilteredFavorites() {
        let favorites = dataManager.favorites

        let categoryFilteredFavorites: [Recipe]

        if let selectedCategory {
            categoryFilteredFavorites = favorites.filter {
                $0.category == selectedCategory
            }
        } else {
            categoryFilteredFavorites = favorites
        }

        filteredFavorites = Dictionary(
            grouping: categoryFilteredFavorites,
            by: {
                String($0.name.prefix(1)).uppercased()
            }
        )
        .mapValues {
            $0.sorted { $0.name < $1.name }
        }
    }

    private func updateRecommendedRecipes() {
        recommendedRecipes = Array(
            dataManager.favorites.shuffled().prefix(5)
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if dataManager.favorites.isEmpty {
                    if dataManager.isLoading {
                        loadingView
                    } else {
                        EmptyFavoritesView()
                            .transition(.opacity)
                    }
                } else {
                    favoritesContent
                }
            }
            .id(accentColorPreference)
            .navigationTitle("Favorite Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(
                    recipe: recipe,
                    navigationPath: $navigationPath
                )
            }
            .onAppear {
                dataManager.syncFavorites()
                dataManager.syncRecentSearches()
                dataManager.fetchRecipes(isManual: false)

                updateRecommendedRecipes()
                updateFilteredFavorites()
            }
            .onChange(of: dataManager.favorites) { _, favorites in
                if let selectedCategory,
                   !favorites.contains(where: {
                       $0.category == selectedCategory
                   }) {
                    self.selectedCategory = nil
                }

                updateRecommendedRecipes()
                updateFilteredFavorites()
            }
            .onChange(of: selectedCategory) { _, _ in
                updateFilteredFavorites()
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: {
                        dataManager.errorMessage != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            dataManager.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    dataManager.errorMessage = nil
                }
            } message: {
                Text(dataManager.errorMessage ?? "Unknown error")
            }
            .dynamicTypeSize(.xSmall ... .accessibility5)
        }
    }

    private var favoritesContent: some View {
        VStack(spacing: 0) {
            if !favoriteCategories.isEmpty {
                categorySelector
            }

            ScrollView {
                LazyVStack(
                    spacing: 0,
                    pinnedViews: [.sectionHeaders]
                ) {
                    if !recommendedRecipes.isEmpty {
                        craftifyPicksSection
                    }

                    FavoritesSection(
                        filteredFavorites: filteredFavorites,
                        navigationPath: $navigationPath,
                        horizontalSizeClass: horizontalSizeClass
                    )
                }
                .scrollContentBackground(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
        }
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: hStackSpacing) {
                categoryButton(
                    title: "All",
                    category: nil,
                    accessibilityLabel: "Show all favorite recipes",
                    accessibilityHint:
                        "Displays all favorite recipes across all categories"
                )

                ForEach(favoriteCategories, id: \.self) { category in
                    categoryButton(
                        title: category,
                        category: category,
                        accessibilityLabel:
                            "Show \(category) favorite recipes",
                        accessibilityHint:
                            "Filters favorite recipes to show only the \(category) category"
                    )
                }
            }
            .padding(
                .horizontal,
                horizontalSizeClass == .regular
                    ? buttonPaddingHorizontal * 1.5
                    : buttonPaddingHorizontal
            )
            .padding(.vertical, buttonPaddingVertical)
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
    }

    private func categoryButton(
        title: String,
        category: String?,
        accessibilityLabel: String,
        accessibilityHint: String
    ) -> some View {
        Button {
            selectedCategory = category
            HapticFeedback.impact()
        } label: {
            Text(title)
                .font(.body)
                .fontWeight(.bold)
                .padding(
                    .horizontal,
                    horizontalSizeClass == .regular
                        ? buttonPaddingHorizontal * 1.5
                        : buttonPaddingHorizontal
                )
                .padding(.vertical, buttonPaddingVertical)
                .background(
                    selectedCategory == category
                        ? Color.userAccentColor
                        : Color.gray.opacity(0.2)
                )
                .foregroundStyle(.white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var craftifyPicksSection: some View {
        Section {
            if isCraftifyPicksExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: hStackSpacing) {
                        ForEach(
                            recommendedRecipes,
                            id: \.name
                        ) { recipe in
                            NavigationLink {
                                RecipeDetailView(
                                    recipe: recipe,
                                    navigationPath: $navigationPath
                                )
                            } label: {
                                RecipeCell(
                                    recipe: recipe,
                                    isCraftifyPick: true
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(
                        .horizontal,
                        horizontalSizeClass == .regular
                            ? buttonPaddingHorizontal * 1.5
                            : buttonPaddingHorizontal
                    )
                    .padding(.vertical, buttonPaddingVertical)
                }
            }
        } header: {
            CraftifyPicksHeader(
                isExpanded: isCraftifyPicksExpanded,
                accentColorPreference: accentColorPreference
            ) {
                withAnimation {
                    isCraftifyPicksExpanded.toggle()
                }
            }
            .background(Color(.systemBackground))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.userAccentColor)

            Text("Loading Favorites…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading Favorites")
        .accessibilityHint(
            "Please wait while your favorite recipes are being loaded"
        )
    }
}
