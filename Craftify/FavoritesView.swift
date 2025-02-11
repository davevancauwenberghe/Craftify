//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var recommendedRecipes: [Recipe] = []
    @State private var selectedCategory: String? = nil  // For category filtering
    @State private var categoryScrollHapticTriggered = false  // For drag haptics
    @State private var isLoading = false // Track loading status

    // Group and filter favorite recipes alphabetically.
    var sortedFavorites: [String: [Recipe]] {
        let favorites = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let categoryFiltered = selectedCategory == nil ? favorites : favorites.filter { $0.category == selectedCategory }
        let filtered = searchText.isEmpty ? categoryFiltered : categoryFiltered.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        return Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) })
            .mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    // Compute the available favorite categories.
    var favoriteCategories: [String] {
        let favorites = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let categories = favorites.compactMap { $0.category.isEmpty ? nil : $0.category }
        return Array(Set(categories)).sorted()
    }
    
    // Total count of favorite recipes (after filtering).
    var recipeCount: Int {
        sortedFavorites.values.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                if isLoading {
                    ProgressView("Loading recipes from Cloud...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    List {
                        // Recipe counter row (updated label).
                        Text("\(recipeCount) favorite recipes available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .listRowSeparator(.hidden)
                        
                        ForEach(sortedFavorites.keys.sorted(), id: \ .self) { letter in
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
                    .refreshable {
                        isLoading = true
                        dataManager.loadData {
                            dataManager.syncFavorites()
                            DispatchQueue.main.async {
                                isLoading = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorite recipes")
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(text: $searchText, prompt: "Search favorites")
        .onAppear {
            isLoading = true
            dataManager.loadData {
                dataManager.syncFavorites()
                DispatchQueue.main.async {
                    isLoading = false
                    recommendedRecipes = Array(
                        dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
                        .shuffled()
                        .prefix(5)
                    )
                }
            }
        }
    }
}
