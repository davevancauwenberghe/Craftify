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
    @State private var isSearching = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                CategoryView(selectedTab: $selectedTab,
                             navigationPath: $navigationPath,
                             searchText: $searchText,
                             isSearching: $isSearching)
                    .navigationTitle("Craftify")
                    .navigationBarTitleDisplayMode(.large)
                    // Attach searchable at the NavigationStack level
                    .searchable(text: $searchText, prompt: "Search recipes")
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
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    
    // State used to throttle haptics during category scroll.
    @State private var categoryScrollHapticTriggered = false

    // Computed property: recipes after filtering (grouped by first letter)
    var sortedRecipes: [String: [Recipe]] {
        let categoryFiltered = selectedCategory == nil
            ? dataManager.recipes
            : dataManager.recipes.filter { $0.category == selectedCategory }
        
        let filtered = searchText.isEmpty ? categoryFiltered : categoryFiltered.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        return Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) })
            .mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    // Computed property for the count of recipes that will be displayed.
    var displayedRecipeCount: Int {
        sortedRecipes.values.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        VStack {
            // Category selection buttons with a drag gesture for haptics
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectedCategory = nil
                    }) {
                        Text("All")
                            .fontWeight(.bold)
                            .padding()
                            .background(selectedCategory == nil ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            selectedCategory = category
                        }) {
                            Text(category)
                                .fontWeight(.bold)
                                .padding()
                                .background(selectedCategory == category ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                // Attach a drag gesture to trigger a haptic when scrolling starts.
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { _ in
                            if !categoryScrollHapticTriggered {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                categoryScrollHapticTriggered = true
                            }
                        }
                        .onEnded { _ in
                            categoryScrollHapticTriggered = false
                        }
                )
            }
            
            // Recommended Recipes Section (Craftify Picks)
            if !recommendedRecipes.isEmpty && !isSearching {
                VStack(alignment: .leading) {
                    Text("Craftify Picks")
                        .font(.title3).bold()
                        .padding(.horizontal)
                    
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
                                            .font(.caption).bold()
                                            .lineLimit(1)
                                            .frame(width: 90)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                }
                                // Haptic feedback for tapping a recommended recipe.
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Recipe counter placed after the Craftify Picks section.
            Text("\(displayedRecipeCount) recipes available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
            
            // Recipes List with category labels under the recipe names
            List {
                ForEach(sortedRecipes.keys.sorted(), id: \.self) { letter in
                    Section(header:
                        Text(letter)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.primary)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray5).opacity(0.5))
                            .cornerRadius(8)
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
                                            .font(.headline).bold()
                                        Text(recipe.category)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            // Haptic feedback for tapping a recipe in the list.
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            )
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            // Removed inner .searchable so that the NavigationStack's search bar remains active.
            .onChange(of: searchText) { _, newValue in
                isSearching = !newValue.isEmpty
            }
            .onAppear {
                selectedTab = 0
                recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
                // (Optional) Clear search text on reappear to force a refresh of the navigation bar.
                // searchText = ""
            }
        }
        .navigationBarTitleDisplayMode(.large)
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
