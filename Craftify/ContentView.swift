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

    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return dataManager.recipes
        } else {
            return dataManager.recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

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

            NavigationView {
                CategoryView()
            }
            .tabItem {
                Label("Categories", systemImage: "square.grid.2x2")
            }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
        }
        .onAppear {
            if dataManager.recipes.isEmpty {
                dataManager.loadData()
            }
        }
    }
}

struct CategoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedCategory: String? = nil
    
    var filteredRecipes: [Recipe] {
        if let category = selectedCategory {
            return dataManager.recipes.filter { $0.category == category }
        } else {
            return dataManager.recipes
        }
    }
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: { selectedCategory = nil }) {
                        Text("All")
                            .padding()
                            .background(selectedCategory == nil ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    ForEach(dataManager.categories, id: \ .self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category)
                                .padding()
                                .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
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
        }
        .navigationTitle("Categories")
    }
}
