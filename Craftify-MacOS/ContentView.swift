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
    @State private var selectedCategory: String? = nil  // Managed by the sidebar

    var body: some View {
        NavigationSplitView {
            // Sidebar: navigation and category selection.
            List {
                Section(header: Text("Navigation").bold()) {
                    NavigationLink(value: "Recipes") {
                        Label("Recipes", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(value: "Favorites") {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    NavigationLink(value: "More") {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
                Section(header: Text("Categories").bold()) {
                    Button("All") {
                        selectedCategory = nil
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Craftify")
            .searchable(text: $searchText, prompt: "Search categories")
        } detail: {
            ZStack {
                if isLoading {
                    ProgressView("Loading recipes from Cloud...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    CategoryView(navigationPath: $navigationPath,
                                 searchText: $searchText,
                                 isSearching: $isSearching,
                                 selectedCategory: $selectedCategory)
                }
            }
            // Removed the .searchable modifier from the detail view to avoid duplicate search toolbar items.
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
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
    }
}

struct CategoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var navigationPath: NavigationPath
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var selectedCategory: String?  // Passed from ContentView
    @State private var recommendedRecipes: [Recipe] = []
    @State private var isCraftifyPicksExpanded = true

    var sortedRecipes: [String: [Recipe]] {
        let categoryFiltered: [Recipe] = {
            if let category = selectedCategory {
                return dataManager.recipes.filter { $0.category == category }
            } else {
                return dataManager.recipes
            }
        }()
        
        let filtered: [Recipe] = {
            if searchText.isEmpty {
                return categoryFiltered
            } else {
                return categoryFiltered.filter { recipe in
                    recipe.name.localizedCaseInsensitiveContains(searchText) ||
                    recipe.category.localizedCaseInsensitiveContains(searchText) ||
                    recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }()
        
        let grouped = Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) })
        return grouped.mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show the current category in a header.
            HStack {
                Text("Category:")
                    .font(.headline)
                if let cat = selectedCategory {
                    Text(cat)
                        .font(.headline)
                        .bold()
                } else {
                    Text("All")
                        .font(.headline)
                        .bold()
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Recommended Recipes ("Craftify Picks") Section.
            if !recommendedRecipes.isEmpty && !isSearching {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: { withAnimation { isCraftifyPicksExpanded.toggle() } }) {
                            Image(systemName: isCraftifyPicksExpanded ? "chevron.down" : "chevron.right")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        Text("Craftify Picks")
                            .font(.title3)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    
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
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            // Main Recipes List.
            List {
                ForEach(sortedRecipes.keys.sorted(), id: \.self) { letter in
                    Section(header:
                        Text(letter)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    ) {
                        ForEach(sortedRecipes[letter] ?? []) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)) {
                                HStack {
                                    Image(recipe.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .padding(4)
                                    VStack(alignment: .leading) {
                                        Text(recipe.name)
                                            .font(.headline)
                                            .bold()
                                        if !recipe.category.isEmpty {
                                            Text(recipe.category)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .onAppear {
                recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
            }
        }
        // Removed an extra navigationTitle here to let the parent view manage it.
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
