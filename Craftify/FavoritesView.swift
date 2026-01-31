//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit
import UIKit

struct EmptyFavoritesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 16

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: "heart.slash")
                .font(.system(size: iconSize))
                .foregroundColor(.gray)
            
            Text("No favorite recipes")
                .font(.title)
                .bold()
            
            Text("You haven't added any favorite recipes yet.\nExplore recipes and tap the heart to mark them as favorites.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, padding)
        }
        .padding(padding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No favorite recipes, You haven't added any favorite recipes yet. Explore recipes and tap the heart to mark them as favorites.")
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct FavoritesSection: View {
    let filteredFavorites: [String: [Recipe]]
    let navigationPath: Binding<NavigationPath>
    let horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var gridSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8

    var body: some View {
        ForEach(filteredFavorites.keys.sorted(), id: \.self) { letter in
            Section {
                if horizontalSizeClass == .regular {
                    // iPad: Two-column grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: gridSpacing),
                            GridItem(.flexible(), spacing: gridSpacing)
                        ],
                        alignment: .leading,
                        spacing: gridSpacing
                    ) {
                        ForEach(filteredFavorites[letter] ?? [], id: \.name) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, navigationPath: navigationPath)
                            } label: {
                                RecipeCell(recipe: recipe, isCraftifyPick: false)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
                } else {
                    // iPhone: Single-column stack
                    ForEach(filteredFavorites[letter] ?? [], id: \.name) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe, navigationPath: navigationPath)
                        } label: {
                            RecipeCell(recipe: recipe, isCraftifyPick: false)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            } header: {
                Text(letter)
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
                    .padding(.vertical, paddingVertical)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var navigationPath = NavigationPath()
    @State private var recommendedRecipes: [Recipe] = []
    @State private var selectedCategory: String? = nil
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredFavorites: [String: [Recipe]] = [:]
    @ScaledMetric(relativeTo: .body) private var buttonPaddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var buttonPaddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var hStackSpacing: CGFloat = 8

    private var favoriteCategories: [String] {
        Array(Set(dataManager.favorites.compactMap { $0.category.isEmpty ? nil : $0.category })).sorted()
    }

    private func updateFilteredFavorites() {
        let favorites = dataManager.favorites
        let byCategory = selectedCategory == nil ? favorites : favorites.filter { $0.category == selectedCategory }
        filteredFavorites = Dictionary(grouping: byCategory, by: { String($0.name.prefix(1).uppercased()) })
            .mapValues { $0.sorted { $0.name < $1.name } }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if !favoriteCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: hStackSpacing) {
                            Button {
                                selectedCategory = nil
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("All")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
                                    .padding(.vertical, buttonPaddingVertical)
                                    .background(selectedCategory == nil ? Color.userAccentColor : Color.gray.opacity(0.2))
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
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
                                        .padding(.vertical, buttonPaddingVertical)
                                        .background(selectedCategory == category ? Color.userAccentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .accessibilityLabel("Show \(category) favorite recipes")
                                .accessibilityHint("Filters favorite recipes to show only \(category) category")
                            }
                        }
                        .id(accentColorPreference)
                        .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
                        .padding(.vertical, buttonPaddingVertical)
                    }
                    .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
                }

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if !recommendedRecipes.isEmpty {
                            Section {
                                if isCraftifyPicksExpanded {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: hStackSpacing) {
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
                                        .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
                                        .padding(.vertical, buttonPaddingVertical)
                                    }
                                }
                            } header: {
                                CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded, accentColorPreference: accentColorPreference) {
                                    withAnimation { isCraftifyPicksExpanded.toggle() }
                                }
                                .background(Color(.systemBackground))
                            }
                        }

                        FavoritesSection(
                            filteredFavorites: filteredFavorites,
                            navigationPath: $navigationPath,
                            horizontalSizeClass: horizontalSizeClass
                        )
                    }
                    .scrollContentBackground(.hidden)
                }
                .id(accentColorPreference)
                .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
            }
            .overlay {
                if dataManager.isLoading && dataManager.favorites.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.userAccentColor)
                        Text("Loading Favorites…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Loading Favorites")
                    .accessibilityHint("Please wait while your favorite recipes are being loaded")
                }
            }
            .navigationTitle("Favorite Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
            }
            .onAppear {
                dataManager.syncFavorites()
                dataManager.syncRecentSearches()
                dataManager.fetchRecipes(isManual: false)
                recommendedRecipes = Array(dataManager.favorites.shuffled().prefix(5))
                updateFilteredFavorites()
            }
            .onChange(of: dataManager.favorites) { _, _ in
                recommendedRecipes = Array(dataManager.favorites.shuffled().prefix(5))
                updateFilteredFavorites()
            }
            .onChange(of: dataManager.isLoading) { _, newValue in
                if !newValue && dataManager.isManualSyncing {
                    // View updates are handled reactively via onChange(of: dataManager.favorites)
                }
            }
            .task(id: selectedCategory) {
                await MainActor.run {
                    updateFilteredFavorites()
                }
            }
            .alert(isPresented: Binding(
                get: { dataManager.errorMessage != nil },
                set: { if !$0 { dataManager.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(dataManager.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .dynamicTypeSize(.xSmall ... .accessibility5)
        }
    }
}
