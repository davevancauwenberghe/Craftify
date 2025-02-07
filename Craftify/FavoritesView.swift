//
//  FavoritesView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var recommendedRecipes: [Recipe] = []

    var filteredFavorites: [Recipe] {
        let favorites = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        
        if searchText.isEmpty {
            return favorites
        } else {
            return favorites.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                if !recommendedRecipes.isEmpty && !isSearching {
                    VStack(alignment: .leading) {
                        Text("Craftify Picks")
                            .font(.title3).bold()
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(recommendedRecipes, id: \ .id) { recipe in
                                    NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                        VStack {
                                            Image(recipe.image)
                                                .resizable()
                                                .frame(width: 90, height: 90)
                                                .padding(4)
                                            Text(recipe.name)
                                                .font(.caption).bold()
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
                }
                
                List {
                    ForEach(filteredFavorites) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                            HStack {
                                Image(recipe.image)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .padding(4)
                                Text(recipe.name)
                                    .font(.headline).bold()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .searchable(text: $searchText, prompt: "Search favorites")
                .onChange(of: searchText) { _, newValue in isSearching = !newValue.isEmpty }
                .onAppear {
                    recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
                }
            }
            .navigationTitle("Favorite Recipes")
        }
    }
}
