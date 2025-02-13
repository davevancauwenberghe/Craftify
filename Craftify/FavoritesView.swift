//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit

// MARK: - Empty Favorites View
struct EmptyFavoritesView: View {
    var body: some View {
        ContentUnavailableView("No Favorite Recipes\nYou haven't added any favorite recipes yet. Explore recipes and tap the heart to mark them as favorites!", systemImage: "heart.slash")
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
    @State private var selectedCategory: String? = nil  // For category filtering
    @State private var categoryScrollHapticTriggered = false  // For drag haptics

    // MARK: - Computed Properties
    
    // Group and filter favorited recipes by their first letter.
    var sortedFavorites: [String: [Recipe]] {
        // Step 1: Filter recipes that are favorites.
        let favoriteRecipes = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        
        // Step 2: Filter by selected category if one is chosen.
        let categoryFiltered: [Recipe]
        if let category = selectedCategory {
            categoryFiltered = favoriteRecipes.filter { $0.category == category }
        } else {
            categoryFiltered = favoriteRecipes
        }
        
        // Step 3: Filter further based on search text.
        let filteredFavorites: [Recipe]
        if searchText.isEmpty {
            filteredFavorites = categoryFiltered
        } else {
            filteredFavorites = categoryFiltered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.ingredients.contains { ingredient in
                    ingredient.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // Step 4: Group recipes by the first letter of their name.
        let grouped = Dictionary(grouping: filteredFavorites, by: { String($0.name.prefix(1)) })
        
        // Step 5: Sort each group alphabetically.
        let sortedGrouped = grouped.mapValues { recipes in
            recipes.sorted { $0.name < $1.name }
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
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        )
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
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
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
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
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
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        categoryScrollHapticTriggered = true
                                    }
                                }
                                .onEnded { _ in
                                    categoryScrollHapticTriggered = false
                                }
                        )
                    }
                }
                
                // Recommended Favorites ("Craftify Picks") with haptics.
                if !recommendedRecipes.isEmpty && !isSearching {
                    VStack(alignment: .leading) {
                        Text("Craftify Picks")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)
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
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(12)
                                    }
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
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
            .navigationBarTitleDisplayMode(.large)
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
