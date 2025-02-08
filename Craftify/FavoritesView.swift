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
    
    var sortedFavorites: [String: [Recipe]] {
        let favorites = dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }
        let filtered = searchText.isEmpty ? favorites : favorites.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        return Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) }).mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                // Recommended Favorites (Craftify Picks) section
                let favoritePicks = sortedFavorites.flatMap { $0.value }.shuffled().prefix(5)
                if !favoritePicks.isEmpty && !isSearching {
                    VStack(alignment: .leading) {
                        Text("Craftify Picks")
                            .font(.title3).bold()
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(favoritePicks) { recipe in
                                    NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                        VStack {
                                            Image(recipe.image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 90, height: 90)
                                                .padding(4)
                                            Text(recipe.name)
                                                .font(.caption).bold()
                                                .lineLimit(1)
                                                .frame(width: 90)
                                        }
                                        .padding()
                                        .background(Color(UIColor.systemGray5))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Favorites List
                List {
                    ForEach(sortedFavorites.keys.sorted(), id: \ .self) { letter in
                        Section(header: Text(letter)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray5).opacity(0.5))
                            .cornerRadius(8)
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
                                                .font(.headline).bold()
                                            Text(recipe.category)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search favorites")
                .onChange(of: searchText) { _, newValue in
                    isSearching = !newValue.isEmpty
                }
            }
            .navigationTitle("Favorite Recipes")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                recommendedRecipes = Array(dataManager.recipes.filter { dataManager.isFavorite(recipe: $0) }.shuffled().prefix(5))
            }
        }
    }
}
