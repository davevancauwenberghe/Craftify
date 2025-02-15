//
//  FavoritesView.swift
//  Craftify-MacOS
//
//  Created by Dave Van Cauwenberghe on 14/02/2025.
//

import SwiftUI
import Combine
import CloudKit

// MARK: - Empty Favorites View
struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No favorite recipes")
                .font(.title)
                .bold()
            Text("You haven't added any favorite recipes yet.\nExplore recipes and click the heart to mark them as favorites.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - FavoritesView
struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var recommendedRecipes: [Recipe] = []
    @State private var selectedCategory: String? = nil
    @State private var categoryScrollHapticTriggered = false
    @State private var isCraftifyPicksExpanded = true

    // MARK: - Computed Properties

    // Group and filter favorited recipes by their first letter.
    var sortedFavorites: [String: [Recipe]] {
        // Filter recipes that are favorites.
        let favoriteRecipes = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        
        // Filter by selected category if one is chosen.
        let categoryFiltered: [Recipe] = {
            if let category = selectedCategory {
                return favoriteRecipes.filter { $0.category == category }
            } else {
                return favoriteRecipes
            }
        }()
        
        // Further filter based on search text.
        let filteredFavorites: [Recipe] = {
            if searchText.isEmpty {
                return categoryFiltered
            } else {
                return categoryFiltered.filter { recipe in
                    recipe.name.localizedCaseInsensitiveContains(searchText) ||
                    recipe.category.localizedCaseInsensitiveContains(searchText) ||
                    recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }()
        
        // Group recipes by the first letter of their name.
        let grouped = Dictionary(grouping: filteredFavorites, by: { String($0.name.prefix(1)) })
        
        // Sort each group alphabetically.
        var sortedGrouped: [String: [Recipe]] = [:]
        for (key, recipes) in grouped {
            sortedGrouped[key] = recipes.sorted { $0.name < $1.name }
        }
        return sortedGrouped
    }
    
    // Compute the available favorite categories.
    var favoriteCategories: [String] {
        let favoriteRecipes = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let categories = favoriteRecipes.compactMap { $0.category.isEmpty ? nil : $0.category }
        return Array(Set(categories)).sorted()
    }
    
    // Total count of favorited recipes (after filtering).
    var recipeCount: Int {
        sortedFavorites.values.reduce(0) { $0 + $1.count }
    }
    
    // Extracted view for the alphabetical favorites list.
    @ViewBuilder
    var favoritesList: some View {
        List {
            ForEach(sortedFavorites.keys.sorted(), id: \.self) { letter in
                Section(header:
                    Text(letter)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                ) {
                    ForEach(sortedFavorites[letter] ?? []) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                            HStack {
                                Image(recipe.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .padding(4)
                                VStack(alignment: .leading) {
                                    Text(recipe.name)
                                        .font(.headline)
                                        .bold()
                                    if !recipe.category.isEmpty {
                                        Text(recipe.category)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                // Horizontal category selection.
                if !favoriteCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button(action: {
                                let generator = NSHapticFeedbackManager.defaultPerformer
                                generator.perform(.alignment, performanceTime: .default)
                                selectedCategory = nil
                            }) {
                                Text("All")
                                    .fontWeight(.bold)
                                    .padding()
                                    .background(selectedCategory == nil ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            ForEach(favoriteCategories, id: \.self) { category in
                                Button(action: {
                                    let generator = NSHapticFeedbackManager.defaultPerformer
                                    generator.perform(.alignment, performanceTime: .default)
                                    selectedCategory = category
                                }) {
                                    Text(category)
                                        .fontWeight(.bold)
                                        .padding()
                                        .background(selectedCategory == category ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { _ in
                                    if !categoryScrollHapticTriggered {
                                        let generator = NSHapticFeedbackManager.defaultPerformer
                                        generator.perform(.alignment, performanceTime: .default)
                                        categoryScrollHapticTriggered = true
                                    }
                                }
                                .onEnded { _ in
                                    categoryScrollHapticTriggered = false
                                }
                        )
                    }
                }
                
                // Recommended Favorites ("Craftify Picks").
                if !recommendedRecipes.isEmpty && !isSearching {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: { withAnimation { isCraftifyPicksExpanded.toggle() } }) {
                                Image(systemName: isCraftifyPicksExpanded ? "chevron.down" : "chevron.right")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            Text("Craftify Picks")
                                .font(.title3)
                                .bold()
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if isCraftifyPicksExpanded {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(recommendedRecipes) { recipe in
                                        NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                            VStack {
                                                Image(recipe.image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 90, height: 90)
                                                    .padding(4)
                                                Text(recipe.name)
                                                    .font(.caption)
                                                    .bold()
                                                    .lineLimit(1)
                                                    .frame(width: 90)
                                            }
                                            .padding()
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // Display ContentUnavailableView if there are no favorite recipes.
                if recipeCount == 0 {
                    EmptyFavoritesView()
                } else {
                    // Otherwise, display the alphabetical favorites list.
                    favoritesList
                }
            }
            .navigationTitle("Favorite recipes")
        }
        .searchable(text: $searchText, prompt: "Search favorites")
        .onChange(of: searchText) { _, newValue in
            isSearching = !newValue.isEmpty
        }
        .onAppear {
            recommendedRecipes = Array(
                dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
                    .shuffled()
                    .prefix(5)
            )
        }
    }
}
