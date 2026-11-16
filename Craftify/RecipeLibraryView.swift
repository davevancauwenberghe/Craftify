//
//  RecipeLibraryView.swift
//  Craftify
//
//  The Recipes tab: category filter, Craftify Picks, and the A–Z recipe list.
//  Moved out of ContentView.swift, which now holds only the tab structure.
//

import SwiftUI

struct RecipesTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    let resetID: UUID

    var body: some View {
        RecipeBrowser(resetID: resetID) { selectedID, openRecipe in
            CategoryView(selectedRecipeID: selectedID, openRecipe: openRecipe)
                .craftifyLibraryTitle("Craftify")
                .overlay {
                    if dataManager.isLoading && dataManager.recipes.isEmpty {
                        CraftifyLoadingState(
                            title: "Preparing Your Recipe Book",
                            detail: "Loading recipes and crafting images…"
                        )
                    }
                }
                .craftifyPage()
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct CategoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("isCraftifyPicksExpanded") private var isCraftifyPicksExpanded = false
    let selectedRecipeID: Int?
    let openRecipe: (Recipe) -> Void
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
                filteredRecipes: filteredRecipes,
                showsRecommendations: selectedCategory == nil,
                selectedRecipeID: selectedRecipeID,
                openRecipe: openRecipe
            )
        }
        .onAppear {
            refreshRecommendations()
            updateFilteredRecipes()
        }
        .onChange(of: dataManager.recipes) { _, _ in
            if let selectedCategory, !dataManager.categories.contains(selectedCategory) {
                self.selectedCategory = nil
            }
            refreshRecommendations()
            updateFilteredRecipes()
        }
        .onChange(of: selectedCategory) { _, _ in updateFilteredRecipes() }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }

    private func refreshRecommendations() {
        let existingIDs = Set(recommendedRecipes.map(\.id))
        let existing = recommendedRecipes.compactMap { previous in
            dataManager.recipes.first { $0.id == previous.id }
        }
        let additions = dataManager.recipes.filter { !existingIDs.contains($0.id) }.shuffled()
        recommendedRecipes = Array((existing + additions).prefix(7))
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

    @Environment(\.craftifyAccentColor) private var accent

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
        .craftifyFloatingSurface(cornerRadius: CraftifyLayout.tileRadius)
        .padding(.horizontal, CraftifyLayout.sidebarPadding)
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
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    isSelected ? accent : Color.primary.opacity(0.055),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(title), selected" : title)
        .accessibilityHint("Filters the recipe library")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct RecipeListView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.craftifyAccentColor) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var recommendedRecipes: [Recipe]
    @Binding var isCraftifyPicksExpanded: Bool
    let filteredRecipes: [String: [Recipe]]
    let showsRecommendations: Bool
    let selectedRecipeID: Int?
    let openRecipe: (Recipe) -> Void

    /// The library is a sidebar column (300–460 pt) or a compact window, never a
    /// wide page. The previous 320 pt adaptive minimum was wider than the
    /// sidebar's content area, so rows overflowed their column on iPad.
    private let recipeColumns = [GridItem(.flexible())]

    var body: some View {
        Group {
            if dataManager.recipes.isEmpty {
                EmptyRecipeView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CraftifyLayout.sectionSpacing) {
                        if showsRecommendations && !recommendedRecipes.isEmpty {
                            picksSection
                        }

                        ForEach(filteredRecipes.keys.sorted(), id: \.self) { letter in
                            recipeSection(letter)
                        }
                    }
                    .craftifyLibraryContent()
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var picksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                withAnimation(reduceMotion ? nil : .snappy) { isCraftifyPicksExpanded.toggle() }
            }

            if isCraftifyPicksExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CraftifyLayout.cardSpacing) {
                        ForEach(recommendedRecipes) { recipe in
                            Button { openRecipe(recipe) } label: {
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
                .foregroundStyle(accent)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: recipeColumns, alignment: .leading, spacing: CraftifyLayout.cardSpacing) {
                ForEach(filteredRecipes[letter] ?? []) { recipe in
                    Button { openRecipe(recipe) } label: {
                        RecipeCell(recipe: recipe, isCraftifyPick: false, isSelected: recipe.id == selectedRecipeID)
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
    var isSelected = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        Group {
            if isCraftifyPick {
                pickContent
                    .craftifyAccentCard(cornerRadius: CraftifyLayout.tileRadius)
            } else {
                rowContent
                    .craftifyCard(cornerRadius: CraftifyLayout.tileRadius)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: CraftifyLayout.tileRadius, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: CraftifyLayout.tileRadius, style: .continuous)
                    .stroke(accent, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("recipe-\(recipe.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.name), \(recipe.category.isEmpty ? "recipe" : "\(recipe.category) recipe")")
        .accessibilityHint("Opens the crafting recipe")
    }

    private var rowContent: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    recipeImage(size: 64)
                    rowLabels
                }
            } else {
                HStack(spacing: 14) {
                    recipeImage(size: 44)
                    rowLabels
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }

    private var rowLabels: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(recipe.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            if !recipe.category.isEmpty {
                Label(recipe.category, systemImage: "tag.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
        }
    }

    private var pickContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                recipeImage(size: horizontalSizeClass == .regular ? 96 : 82)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
                CraftifyStatusPill(title: "Pick", symbol: "sparkles")
                    .padding(9)
            }
            .frame(height: horizontalSizeClass == .regular ? 142 : 124)

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
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct CraftifyPicksHeader: View {
    let isExpanded: Bool
    let toggle: () -> Void
    @Environment(\.craftifyAccentColor) private var accent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dynamicTypeSize.isAccessibilitySize ? "Picks" : "Craftify Picks")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    if isExpanded {
                        Text("A fresh handful from the recipe book")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse Craftify Picks" : "Expand Craftify Picks")
        .accessibilityHint("Shows or hides recommended recipes")
    }
}
