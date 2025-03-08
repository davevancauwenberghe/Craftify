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
        VStack(spacing: 12) { // Added spacing between elements
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("No favorite recipes")
                .font(.title)
                .bold()
            
            Text("You haven't added any favorite recipes yet.\nExplore recipes and tap the heart to mark them as favorites.")
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
    @State private var isCraftifyPicksExpanded = true // For collapsible Craftify Picks

    var sortedFavorites: [String: [Recipe]] {
        let favoriteRecipes = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let categoryFiltered = selectedCategory != nil ? favoriteRecipes.filter { $0.category == selectedCategory } : favoriteRecipes
        let filteredFavorites = searchText.isEmpty ? categoryFiltered : categoryFiltered.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.category.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        let grouped = Dictionary(grouping: filteredFavorites, by: { String($0.name.prefix(1)) })
        return grouped.mapValues { $0.sorted { $0.name < $1.name } }
    }

    var favoriteCategories: [String] {
        let categories = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
            .compactMap { $0.category.isEmpty ? nil : $0.category }
        return Array(Set(categories)).sorted()
    }
    
    var recipeCount: Int {
        sortedFavorites.values.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                // Category horizontal scroll view.
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
                    }
                    
                    // Combine the Craftify Picks section with the favorites list in one List.
                    List {
                        // Craftify Picks Section.
                        if !recommendedRecipes.isEmpty && !isSearching {
                            Section {
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
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(12)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            } header: {
                                CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                                    withAnimation {
                                        isCraftifyPicksExpanded.toggle()
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        
                        // Favorites List Sections.
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
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                } else {
                    // If no favorites, show the empty state.
                    EmptyFavoritesView()
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
