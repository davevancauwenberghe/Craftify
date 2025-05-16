//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No favorite recipes, You haven't added any favorite recipes yet. Explore recipes and tap the heart to mark them as favorites.")
    }
}

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationPath = NavigationPath()
    @State private var recommendedRecipes: [Recipe] = []
    @State private var selectedCategory: String? = nil
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredFavorites: [String: [Recipe]] = [:]
    
    private let primaryColor = Color(hex: "00AA00")
    
    private var favoriteRecipes: [Recipe] {
        dataManager.favorites.compactMap { name in
            dataManager.recipes.first(where: { $0.name == name })
        }
    }
    
    private var favoriteCategories: [String] {
        Array(Set(favoriteRecipes.compactMap { $0.category.isEmpty ? nil : $0.category })).sorted()
    }
    
    private func updateFilteredFavorites() {
        let byCategory = selectedCategory == nil ? favoriteRecipes : favoriteRecipes.filter { $0.category == selectedCategory }
        filteredFavorites = Dictionary(grouping: byCategory, by: { String($0.name.prefix(1).uppercased()) })
            .mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if filteredFavorites.isEmpty {
                    EmptyFavoritesView()
                } else {
                    if !favoriteCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    selectedCategory = nil
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("All")
                                        .fontWeight(.bold)
                                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
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
                                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == category ? primaryColor : Color.gray.opacity(0.2))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .accessibilityLabel("Show \(category) favorite recipes")
                                    .accessibilityHint("Filters favorite recipes to show only \(category) category")
                                }
                            }
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .padding(.vertical, 8)
                        }
                        .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            if !recommendedRecipes.isEmpty {
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
                                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
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
                            
                            ForEach(filteredFavorites.keys.sorted(), id: \.self) { letter in
                                Section {
                                    ForEach(filteredFavorites[letter] ?? [], id: \.name) { recipe in
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
                                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemBackground))
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
                }
            }
            .navigationTitle("Favorite Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                dataManager.syncFavorites()
                recommendedRecipes = Array(favoriteRecipes.shuffled().prefix(5))
                updateFilteredFavorites()
            }
            .onChange(of: dataManager.favorites) { _, _ in
                recommendedRecipes = Array(favoriteRecipes.shuffled().prefix(5))
                updateFilteredFavorites()
            }
            .task(id: selectedCategory) {
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
        }
    }
}
