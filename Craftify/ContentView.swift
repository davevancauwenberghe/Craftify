//
//  ContentView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager  // Access DataManager via EnvironmentObject
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                CategoryView(selectedTab: $selectedTab, navigationPath: $navigationPath)
            }
            .tabItem {
                Label("Recipes", systemImage: "square.grid.2x2")
            }
            .tag(0)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(1)
        }
        .onAppear {
            if dataManager.recipes.isEmpty {
                dataManager.loadData()
            }
            dataManager.syncFavorites()
        }
    }
}

struct CategoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    
    var filteredRecipes: [Recipe] {
        let categoryFiltered = selectedCategory == nil ? dataManager.recipes : dataManager.recipes.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: { selectedCategory = nil }) {
                        Text("All")
                            .padding()
                            .background(selectedCategory == nil ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    ForEach(dataManager.categories, id: \ .self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category)
                                .padding()
                                .background(selectedCategory == category ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            List(filteredRecipes) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                    HStack {
                        Image(recipe.image)
                            .resizable()
                            .frame(width: 50, height: 50)
                        Text(recipe.name)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
        }
        .navigationTitle("Craftify")
        .onAppear {
            selectedTab = 0 // Reset to homepage when Recipes tab is tapped
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}
