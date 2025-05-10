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
    @State private var isSearchActive = false
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

    init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().isTranslucent = false
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if filteredFavorites.isEmpty {
                    EmptyFavoritesView()
                } else {
                    // Category filter bar
                    if !favoriteCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    selectedCategory = nil
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("All")
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
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
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == category ? primaryColor : Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .accessibilityLabel("Show \(category) favorite recipes")
                                    .accessibilityHint("Filters favorite recipes to show only \(category) category")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }

                    // Favorites List
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // Craftify Picks Section
                            if !recommendedRecipes.isEmpty && !isSearching {
                                Section {
                                    if isCraftifyPicksExpanded {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            LazyHStack(spacing: 8) {
                                                ForEach(recommendedRecipes, id: \.name) { recipe in
                                                    NavigationLink {
                                                        RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                                    } label: {
                                                        RecipeCell(recipe: recipe, isCraftifyPick: true)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .contentShape(Rectangle())
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                        }
                                    }
                                } header: {
                                    CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                                        withAnimation { isCraftifyPicksExpanded.toggle() }
                                    }
                                    .background(Color(.systemBackground))
                                }
                            }

                            // Favorite recipe sections
                            ForEach(filteredFavorites.keys.sorted(), id: \.self) { letter in
                                Section {
                                    ForEach(filteredFavorites[letter]!, id: \.name) { recipe in
                                        NavigationLink {
                                            RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                        } label: {
                                            RecipeCell(recipe: recipe, isCraftifyPick: false)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                    }
                                } header: {
                                    Text(letter)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemBackground))
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Favorite Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search favorites"
            )
            .onChange(of: searchText) {
                isSearching = !searchText.isEmpty
            }
            .onChange(of: isSearchActive) {
                if !isSearchActive {
                    searchText = ""
                }
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
