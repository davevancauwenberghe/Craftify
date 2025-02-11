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
    @EnvironmentObject var dataManager: DataManager  // Access DataManager via EnvironmentObject
    
    // Persist the user's appearance preference ("system", "light", or "dark")
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var isSearching = false
    @State private var isLoading = true // Track loading status

    var body: some View {
        TabView(selection: $selectedTab) {
            // Recipes Tab using CategoryView
            NavigationStack(path: $navigationPath) {
                ZStack {
                    if isLoading {
                        ProgressView("Loading recipes from Cloud...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else {
                        CategoryView(selectedTab: $selectedTab,
                                     navigationPath: $navigationPath,
                                     searchText: $searchText,
                                     isSearching: $isSearching)
                    }
                }
                .navigationTitle("Craftify")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search recipes")
                // Pull-to-refresh: when pulled, reload data from CloudKit.
                .refreshable {
                    isLoading = true
                    dataManager.loadData {
                        dataManager.syncFavorites()
                        isLoading = false
                    }
                }
            }
            .tabItem {
                Label("Recipes", systemImage: "square.grid.2x2")
            }
            .tag(0)
            
            // Favorites Tab
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(1)
            
            // More Tab
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(2)
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
        .onAppear {
            if dataManager.recipes.isEmpty {
                dataManager.loadData {
                    dataManager.syncFavorites()
                    isLoading = false // Hide loading indicator once data is loaded
                }
            } else {
                dataManager.syncFavorites()
                isLoading = false
            }
        }
    }
}


struct CategoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    
    // State used to throttle haptics during category scrolling.
    @State private var categoryScrollHapticTriggered = false

    // Computed property: recipes after filtering, grouped by first letter
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
            // Horizontal category selection with haptics
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
                // Use a simultaneous gesture on the scrolling area to trigger haptics on scroll.
                .simultaneousGesture(
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
                        .font(.title3)
                        .bold()
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
                                            .font(.caption)
                                            .bold()
                                            .lineLimit(1)
                                            .frame(width: 90)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                }
                                // Removed extra gesture on the recommended recipes to avoid interfering with NavigationLink activation.
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Recipes List (with recipe counter as the first row)
            List {
                Text("\(displayedRecipeCount) recipes available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .listRowSeparator(.hidden)
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
                            // Removed the simultaneous gesture here so that the NavigationLink is reliably triggered.
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                isSearching = !newValue.isEmpty
            }
            .onAppear {
                // Set recommendedRecipes to 5 random recipes from all recipes.
                recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
            }
        }
        .navigationTitle("Craftify")
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
