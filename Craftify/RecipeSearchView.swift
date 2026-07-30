//
//  RecipeSearchView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 15/05/2025.
//

import SwiftUI
import UIKit
import Combine
import CloudKit

struct RecipeSearchView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var filteredRecipes: [String: [Recipe]] = [:]
    @State private var navigationPath = NavigationPath()
    @State private var searchFilter: SearchFilter = .all

    enum SearchFilter: String, CaseIterable, Identifiable {
        case all = "Names & Ingredients"
        case names = "Recipe Names"
        case ingredients = "Ingredients"

        var id: Self { self }
    }

    // Resolve synced history names to recipes available on this device.
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
        return Array(recipes.prefix(10))
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
        let filtered = searchText.isEmpty ? dataManager.recipes :
            dataManager.recipes.filter { recipe in
                switch searchFilter {
                case .all:
                    return recipe.name.localizedCaseInsensitiveContains(searchText)
                        || recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
                case .names:
                    return recipe.name.localizedCaseInsensitiveContains(searchText)
                case .ingredients:
                    return recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
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
                                    .foregroundColor(Color.userAccentColor.opacity(0.8))
                                Text("Search for Recipes")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Find recipes by name or ingredients.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                            }
                            .padding(.vertical, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Search for Recipes")
                            .accessibilityHint("Enter a search term to find recipes by name or ingredients")
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
                                        HapticFeedback.impact(.medium)
                                    }) {
                                        Text("Clear All")
                                            .font(.subheadline)
                                            .foregroundColor(Color.userAccentColor)
                                    }
                                    .disabled(recentSearchRecipes.isEmpty)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel("Clear All Recent Searches")
                                    .accessibilityHint("Removes all recent search history")
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                                .background(Color(.systemGroupedBackground))
                                .id(accentColorPreference)

                                RecentSearchesList(
                                    recipes: recentSearchRecipes,
                                    navigationPath: $navigationPath,
                                    accentColorPreference: accentColorPreference
                                )
                            }
                            .padding(.vertical, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Recent Searches")
                            .accessibilityHint("Shows the last 10 recipes you opened from search")
                        }
                    } else {
                        if searchText.isEmpty {
                            // Show placeholder when search bar is tapped but no text is entered
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.userAccentColor.opacity(0.8))
                                Text("Start Searching")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Enter a recipe name or ingredient to start searching.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                            }
                            .padding(.vertical, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Start Searching")
                            .accessibilityHint("Enter a recipe name or ingredient to find recipes")
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
                                Text("Try adjusting your search term or search in another field.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 48 : 32)
                            }
                            .padding(.vertical, 32)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No recipes found")
                            .accessibilityHint("No recipes match your search term. Try adjusting it or search in another field.")
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
                                                        HapticFeedback.impact()
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
                                            .background(Color(.systemGroupedBackground))
                                    }
                                }
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .id(accentColorPreference)
            .overlay {
                if dataManager.isLoading && dataManager.recipes.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.userAccentColor)
                        Text("Loading Recipes…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Loading Recipes")
                    .accessibilityHint("Please wait while the recipes are being loaded")
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SearchFilter.allCases) { filter in
                            Button {
                                searchFilter = filter
                                updateFilteredRecipes()
                                HapticFeedback.selection()
                            } label: {
                                Label(filter.rawValue, systemImage: searchFilter == filter ? "checkmark" : "magnifyingglass")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Search in \(searchFilter.rawValue)")
                    .accessibilityHint("Choose whether to search recipe names, ingredients, or both")
                }
            }
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
            .onChange(of: dataManager.isLoading) { _, newValue in
                if !newValue && dataManager.isManualSyncing {
                    updateFilteredRecipes()
                }
            }
            .task(id: searchText) {
                await MainActor.run {
                    updateFilteredRecipes()
                }
            }
            .onAppear {
                // Sync chests, recent searches, and fetch recipes
                dataManager.syncChests()
                dataManager.syncRecentSearches()
                dataManager.fetchRecipes(isManual: false)
                updateFilteredRecipes()
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
            }
            .dynamicTypeSize(.xSmall ... .accessibility5)
        }
    }
}

// A compact view for displaying recent search items
struct RecentSearchItem: View {
    let recipe: Recipe
    let accentColorPreference: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
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
                .foregroundColor(Color.userAccentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name) recent search")
        .accessibilityHint("Navigates to the detailed view of \(recipe.name)")
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

// Extracted view for the recent searches list
struct RecentSearchesList: View {
    let recipes: [Recipe]
    @Binding var navigationPath: NavigationPath
    let accentColorPreference: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(recipes.enumerated()), id: \.element.name) { index, recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                } label: {
                    RecentSearchItem(recipe: recipe, accentColorPreference: accentColorPreference)
                }
                .buttonStyle(.plain)
                
                if index < recipes.count - 1 {
                    Divider()
                        .padding(.leading, horizontalSizeClass == .regular ? 56 : 48)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
