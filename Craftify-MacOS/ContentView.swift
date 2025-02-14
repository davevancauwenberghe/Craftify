//
//  ContentView.swift
//  Craftify-MacOS
//
//  Created by Dave Van Cauwenberghe on 14/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @State private var isSearching = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: CategoryView(navigationPath: $navigationPath, searchText: $searchText, isSearching: $isSearching)) {
                    Label("Recipes", systemImage: "square.grid.2x2")
                }
                NavigationLink(destination: FavoritesView()) {
                    Label("Favorites", systemImage: "heart.fill")
                }
                NavigationLink(destination: MoreView()) {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Craftify")
        } detail: {
            ZStack {
                if isLoading {
                    ProgressView("Loading recipes from Cloud...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    CategoryView(navigationPath: $navigationPath, searchText: $searchText, isSearching: $isSearching)
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
        }
        .onAppear {
            if dataManager.recipes.isEmpty {
                dataManager.loadData {
                    dataManager.syncFavorites()
                    isLoading = false
                }
            } else {
                dataManager.syncFavorites()
                isLoading = false
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct CategoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var navigationPath: NavigationPath
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    @State private var isCraftifyPicksExpanded = true

    var sortedRecipes: [String: [Recipe]] {
        let categoryFiltered = selectedCategory == nil
            ? dataManager.recipes
            : dataManager.recipes.filter { $0.category == selectedCategory }
        
        let filtered = searchText.isEmpty ? categoryFiltered : categoryFiltered.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.category.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        return Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) })
            .mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    var body: some View {
        VStack {
            List {
                Section(header: Text("Categories").bold()) {
                    Button("All") { selectedCategory = nil }
                    ForEach(dataManager.categories, id: \ .self) { category in
                        Button(category) { selectedCategory = category }
                    }
                }
                
                if !recommendedRecipes.isEmpty && !isSearching {
                    Section(header: HStack {
                        Button(action: { withAnimation { isCraftifyPicksExpanded.toggle() } }) {
                            Image(systemName: isCraftifyPicksExpanded ? "chevron.down" : "chevron.right")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        Text("Craftify Picks").bold()
                    }) {
                        if isCraftifyPicksExpanded {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(recommendedRecipes) { recipe in
                                        NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                            VStack {
                                                Image(recipe.image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 90, height: 90)
                                                    .padding(4)
                                                Text(recipe.name)
                                                    .font(.caption)
                                                    .bold()
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
                }
                
                ForEach(sortedRecipes.keys.sorted(), id: \ .self) { letter in
                    Section(header: Text(letter).bold()) {
                        ForEach(sortedRecipes[letter] ?? []) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                HStack {
                                    Image(recipe.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .padding(4)
                                    VStack(alignment: .leading) {
                                        Text(recipe.name).bold()
                                        if !recipe.category.isEmpty {
                                            Text(recipe.category)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onAppear { recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5)) }
        }
        .navigationTitle("Craftify")
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
