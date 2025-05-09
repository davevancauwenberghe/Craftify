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
        VStack(spacing: 12) {
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
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredFavorites: [String: [Recipe]] = [:]

    private let primaryColor = Color(hex: "00AA00")

    private var favoriteCategories: [String] {
        let cats = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
            .compactMap { $0.category.isEmpty ? nil : $0.category }
        return Array(Set(cats)).sorted()
    }

    private func updateFilteredFavorites() {
        let favorites = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let byCategory = selectedCategory == nil ? favorites : favorites.filter { $0.category == selectedCategory }
        let filtered = searchText.isEmpty ? byCategory : byCategory.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.category.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        let grouped = Dictionary(grouping: filtered, by: { String($0.name.prefix(1).uppercased()) })
        filteredFavorites = grouped.mapValues { $0.sorted { $0.name < $1.name } }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                if filteredFavorites.isEmpty {
                    EmptyFavoritesView()
                } else {
                    // Category filter bar
                    if !favoriteCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Button {
                                    selectedCategory = nil
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("All")
                                        .fontWeight(.bold)
                                        .padding()
                                        .background(selectedCategory == nil ? primaryColor : Color.gray.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .accessibilityLabel("Show all favorite recipes")
                                .accessibilityHint("Displays all favorite recipes across all categories")
                                
                                ForEach(favoriteCategories, id: \.self) { category in
                                    Button {
                                        selectedCategory = category
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text(category)
                                            .fontWeight(.bold)
                                            .padding()
                                            .background(selectedCategory == category ? primaryColor : Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .accessibilityLabel("Show \(category) favorite recipes")
                                    .accessibilityHint("Filters favorite recipes to show only \(category) category")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Favorites List
                    List {
                        // Craftify Picks (unchanged)
                        if !recommendedRecipes.isEmpty && !isSearching {
                            Section(header:
                                CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                                    withAnimation { isCraftifyPicksExpanded.toggle() }
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            ) {
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
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // Favorite recipe sections
                        ForEach(filteredFavorites.keys.sorted(), id: \.self) { letter in
                            Section(header:
                                Text(letter)
                                    .font(.headline)
                                    .bold()
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                            ) {
                                ForEach(filteredFavorites[letter]!) { recipe in
                                    NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                        HStack {
                                            Image(recipe.image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                                .padding(4)
                                                .accessibilityLabel("Image of \(recipe.name)")
                                                .accessibilityHidden(false)
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
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(TapGesture().onEnded {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    })
                                    .padding(.vertical, 4)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Favorite Recipes")
            .navigationBarTitleDisplayMode(.large)
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
                updateFilteredFavorites()
            }
            .task(id: "\(searchText)\(selectedCategory ?? "")") {
                updateFilteredFavorites()
            }
        }
    }
}
