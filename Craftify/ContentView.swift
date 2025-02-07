//
//  ContentView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager  // Access DataManager via EnvironmentObject
    @State private var searchText = ""

    var body: some View {
        TabView {
            NavigationView {
                List(filteredRecipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        HStack {
                            Image(recipe.image)
                                .resizable()
                                .frame(width: 50, height: 50)
                            Text(recipe.name)
                        }
                    }
                }
                .navigationTitle("Craftify")
                .searchable(text: $searchText, prompt: "Search recipes")
            }
            .tabItem {
                Label("Recipes", systemImage: "list.dash")
            }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
        }
        .onAppear {
            // Ensure recipes are loaded when the view appears
            if dataManager.recipes.isEmpty {
                dataManager.loadData()  // Make sure loadData is implemented correctly in your DataManager
            }
        }
    }

    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return dataManager.recipes
        } else {
            return dataManager.recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

