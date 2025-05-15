//
//  RecipeSearchView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 15/05/2025.
//

import SwiftUI
import Combine
import CloudKit

struct RecipeSearchView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var filteredRecipes: [String: [Recipe]] = [:]
    @State private var navigationPath = NavigationPath()
    @State private var searchFilter: SearchFilter = .all
    
    private let primaryColor = Color(hex: "00AA00")
    
    enum SearchFilter: String, CaseIterable {
        case all = "All recipes"
        case favorites = "Favorite Recipes"
    }
    
    // Computed property to get recent search recipes, filtered by searchFilter
    private var recentSearchRecipes: [Recipe] {
        var recipes: [Recipe] = []
        for name in dataManager.recentSearchNames {
            if let recipe = dataManager.recipes.first(where: { $0.name == name }),
               !recipes.contains(where: { $0.name == name }) {
                recipes.append(recipe)
            } else {
                print("Skipping invalid recent search name: \(name) - no matching recipe found")
            }
        }
        // Apply filter to recent searches, limit set to 10
        return Array((searchFilter == .all ? recipes : recipes.filter { recipe in dataManager.favorites.contains { $0.id == recipe.id } }).prefix(10))
    }
    
    // Save a new recent search using DataManager
    private func saveRecentSearch(_ recipe: Recipe) {
        dataManager.saveRecentSearch(recipe)
    }
    
    // Clear all recent searches using DataManager
    private func clearRecentSearches() {
        dataManager.clearRecentSearches()
    }
    
    private func updateFilteredRecipes() {
        // Start with either all recipes or favorited recipes based on the filter
        let baseRecipes = searchFilter == .all ? dataManager.recipes : dataManager.favorites
        
        let filtered = searchText.isEmpty ? baseRecipes :
            baseRecipes.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.category.localizedCaseInsensitiveContains(searchText) ||
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        
        var groups = [String: [Recipe]]()
        for recipe in filtered {
            let key = String(recipe.name.prefix(1).uppercased())
            groups[key, default: []].append(recipe)
        }
        for key in groups.keys {
            groups[key]?.sort(by: { $0.name < $1.name })
        }
        filteredRecipes = groups
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if searchText.isEmpty && !isSearchActive {
                        // Initial state when not searching
                        if recentSearchRecipes.isEmpty {
                            // No recent searches
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(primaryColor.opacity(0.8))
                                Text("Search for Recipes")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Find recipes by name, category, or ingredients.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                            }
                            .padding(.vertical, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Search for Recipes")
                            .accessibilityHint("Enter a search term to find recipes by name, category, or ingredients")
                        } else {
                            // Show recent searches
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Recent Searches")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        clearRecentSearches()
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }) {
                                        Text("Clear All")
                                            .font(.subheadline)
                                            .foregroundColor(primaryColor)
                                    }
                                    .disabled(recentSearchRecipes.isEmpty)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel("Clear All Recent Searches")
                                    .accessibilityHint("Removes all recent search history")
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                                .background(Color(.systemBackground))
                                
                                RecentSearchesList(
                                    recipes: recentSearchRecipes,
                                    navigationPath: $navigationPath
                                )
                            }
                            .padding(.vertical, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Recent Searches")
                            .accessibilityHint("Shows the last 10 recipes you searched for")
                        }
                    } else {
                        // Search filter picker (always visible when search is active)
                        Picker("Search Filter", selection: $searchFilter) {
                            ForEach(SearchFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                        .padding(.vertical, 8)
                        .accessibilityLabel("Search Filter")
                        .accessibilityHint("Choose to search all recipes or only favorite recipes")
                        .onChange(of: searchFilter) { _, _ in
                            updateFilteredRecipes()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        
                        if searchText.isEmpty {
                            // Show recent searches when search bar is tapped but no text is entered
                            if recentSearchRecipes.isEmpty {
                                // No recent searches
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(primaryColor.opacity(0.8))
                                    Text("No Recent Searches")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text("Your recent searches will appear here.\nStart searching to populate this list.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                                }
                                .padding(.vertical, 16)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("No Recent Searches")
                                .accessibilityHint("Your recent searches will appear here. Start searching to populate this list.")
                            } else {
                                // Show filtered recent searches
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Recent Searches")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            clearRecentSearches()
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }) {
                                            Text("Clear All")
                                                .font(.subheadline)
                                                .foregroundColor(primaryColor)
                                        }
                                        .disabled(recentSearchRecipes.isEmpty)
                                        .contentShape(Rectangle())
                                        .accessibilityLabel("Clear All Recent Searches")
                                        .accessibilityHint("Removes all recent search history")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                    .background(Color(.systemBackground))
                                    
                                    RecentSearchesList(
                                        recipes: recentSearchRecipes,
                                        navigationPath: $navigationPath
                                    )
                                }
                                .padding(.vertical, 16)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Recent Searches")
                                .accessibilityHint("Shows the last 10 recipes you searched for")
                            }
                        } else if searchFilter == .favorites && dataManager.favorites.isEmpty {
                            // Empty state when no favorite recipes exist and filter is set to favorites
                            VStack(spacing: 16) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(primaryColor.opacity(0.8))
                                Text("No Favorite Recipes")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("You haven't favorited any recipes yet.\nAdd some favorites or switch to All recipes.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                            }
                            .padding(.vertical, 32)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No Favorite Recipes")
                            .accessibilityHint("You haven't favorited any recipes yet. Add some favorites or switch to All recipes.")
                        } else if !searchText.isEmpty && filteredRecipes.isEmpty {
                            // Empty state when no recipes are found after searching
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.8))
                                Text("No recipes found")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Try adjusting your search term\(searchFilter == .favorites ? " or switch to All recipes" : "").")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                            }
                            .padding(.vertical, 32)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No recipes found")
                            .accessibilityHint("No recipes match your search term. Try adjusting your search\(searchFilter == .favorites ? " or switch to All recipes" : "").")
                        } else {
                            // Search results
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(filteredRecipes.keys.sorted(), id: \.self) { letter in
                                    Section {
                                        ForEach(filteredRecipes[letter] ?? [], id: \.name) { recipe in
                                            NavigationLink {
                                                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                                    .onAppear {
                                                        saveRecentSearch(recipe)
                                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    }
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
                                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemBackground))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .searchable(
                text: $searchText,
                isPresented: $isSearchActive,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes"
            )
            .onChange(of: isSearchActive) { _, newValue in
                if !newValue {
                    searchText = ""
                }
            }
            .task(id: searchText) {
                updateFilteredRecipes()
            }
        }
    }
}

// A compact view for displaying recent search items
struct RecentSearchItem: View {
    let recipe: Recipe
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private let primaryColor = Color(hex: "00AA00")
    
    var body: some View {
        HStack(spacing: 12) {
            Image(recipe.image)
                .resizable()
                .scaledToFit()
                .frame(width: horizontalSizeClass == .regular ? 40 : 32, height: horizontalSizeClass == .regular ? 40 : 32)
                .cornerRadius(6)
                .accessibilityLabel("Image of \(recipe.name)")
            
            Text(recipe.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name) recent search")
        .accessibilityHint("Navigates to the detailed view of \(recipe.name)")
    }
}

// Extracted view for the recent searches list
struct RecentSearchesList: View {
    let recipes: [Recipe]
    @Binding var navigationPath: NavigationPath
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(recipes.enumerated()), id: \.element.name) { index, recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                } label: {
                    RecentSearchItem(recipe: recipe)
                }
                .buttonStyle(.plain)
                
                if index < recipes.count - 1 {
                    Divider()
                        .padding(.leading, horizontalSizeClass == .regular ? 56 : 48)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
    }
}
