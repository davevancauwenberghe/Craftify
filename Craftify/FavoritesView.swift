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
    
    // Favorite categories for horizontal filtering.
    var favoriteCategories: [String] {
        let favorites = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let categories = favorites.compactMap { $0.category.isEmpty ? nil : $0.category }
        return Array(Set(categories)).sorted()
    }
    
    // Total count of favorite recipes after filtering.
    var recipeCount: Int {
        sortedFavorites.values.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                // Horizontal category selection with haptics.
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
                
                // Recommended Favorites (Craftify Picks) section.
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
                
                // Favorite Recipes List with a recipe counter at the top.
                List {
                    // Recipe counter row.
                    Text("\(recipeCount) favorite recipes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                    
                    ForEach(sortedFavorites.keys.sorted(), id: \.self) { letter in
                        Section(header:
                            // Section header: plain text without extra background.
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
                .onChange(of: searchText) { _, newValue in
                    isSearching = !newValue.isEmpty
                }
                .onAppear {
                    // Set recommendedRecipes to 5 random favorite recipes.
                    recommendedRecipes = Array(
                        dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
                        .shuffled()
                        .prefix(5)
                    )
                }
            }
            .navigationTitle("Favorite recipes")
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(text: $searchText, prompt: "Search favorites")
    }
}
