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
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var isSearching = false
    @State private var isLoading = true

    var body: some View {
        TabView(selection: $selectedTab) {
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
        .task {
            if dataManager.recipes.isEmpty {
                await dataManager.loadDataAsync()
            }
            dataManager.syncFavorites()
            isLoading = false
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
            // Categories horizontal scroll view remains pinned at the top.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: { selectedCategory = nil }) {
                        Text("All")
                            .fontWeight(.bold)
                            .padding()
                            .background(selectedCategory == nil ? Color(hex: "00AA00") : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
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
            }
            
            // Embedding both the Craftify Picks and the Recipe List into one List.
            List {
                // Craftify Picks Section with custom header.
                if !recommendedRecipes.isEmpty && !isSearching {
                    Section {
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
                    } header: {
                        CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                            withAnimation {
                                isCraftifyPicksExpanded.toggle()
                            }
                        }
                        // Remove any additional list styling for this header.
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // Recipe List Sections.
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
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            )
                            .padding(.vertical, 4)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .onAppear {
                recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
            }
        }
        .navigationTitle("Craftify")
        .navigationBarTitleDisplayMode(.large)
    }
}

// Custom header view for Craftify Picks to restore original spacing.
struct CraftifyPicksHeader: View {
    var isExpanded: Bool
    var toggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            Text("Craftify Picks")
                .font(.title3)
                .bold()
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8) // Adjust this vertical padding as needed to match your original design.
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

