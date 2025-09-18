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
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                        .cornerRadius(10)
                } else {
                    Color(.systemBackground)
                }
            }
        )
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
                    .background(
                        Group {
                            if #available(iOS 26.0, *) {
                                VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                            } else {
                                Color(.systemBackground)
                            }
                        }
                    )
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @State private var navigationPath = NavigationPath()
    @State private var recommendedRecipes: [Recipe] = []
    @State private var selectedCategory: String? = nil
    @State private var isCraftifyPicksExpanded: Bool = true
    @State private var filteredFavorites: [String: [Recipe]] = [:]

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
        ZStack {
            // 1) solid base so the view never floats transparent
            Color(.systemBackground)
                .ignoresSafeArea()

            // 2) main content
            NavigationStack(path: $navigationPath) {
                ZStack {
                    if dataManager.isLoading && dataManager.favorites.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.userAccentColor)
                                .accessibilityValue("Loading")
                            Text("Loading Favorites…")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Loading Favorites")
                        .accessibilityHint("Please wait while your favorite recipes are being loaded")
                    } else {
                        VStack(spacing: 0) {
                            if filteredFavorites.isEmpty {
                                EmptyFavoritesView()
                            } else {
                                CategoryFilterBar(
                                    selectedCategory: $selectedCategory,
                                    categories: favoriteCategories,
                                    horizontalSizeClass: horizontalSizeClass
                                )

                                RecipeListView(
                                    recommendedRecipes: $recommendedRecipes,
                                    isCraftifyPicksExpanded: $isCraftifyPicksExpanded,
                                    filteredRecipes: filteredFavorites,
                                    navigationPath: $navigationPath,
                                    horizontalSizeClass: horizontalSizeClass,
                                    accentColorPreference: accentColorPreference
                                )
                            }
                        }
                        .navigationTitle("Favorite Recipes")
                        .navigationBarTitleDisplayMode(.large)
                    }
                }
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .background {
                    if #available(iOS 26.0, *) {
                        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                            .ignoresSafeArea()
                    }
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
                .onChange(of: selectedCategory) { _, _ in
                    updateFilteredFavorites()
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

            // 3) manual-sync overlay
            if dataManager.isManualSyncing {
                SyncOverlayView(
                    horizontalSizeClass: horizontalSizeClass,
                    message: "Syncing Favorites…"
                )
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                                .ignoresSafeArea()
                        } else {
                            Color.clear
                        }
                    }
                )
                .opacity(1)
                .animation(.easeInOut(duration: 0.3), value: dataManager.isManualSyncing)
            }
        }
        .accentColor(Color.userAccentColor)
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
                (colorSchemePreference == "light" ? .light : .dark)
        )
    }
}
