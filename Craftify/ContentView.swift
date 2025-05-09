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

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                ZStack {
                    if isLoading {
                        ProgressView("Loading recipes from Cloud...")
                            .progressViewStyle(.circular)
                            .padding()
                    } else {
                        CategoryView(
                            selectedTab: $selectedTab,
                            navigationPath: $navigationPath,
                            searchText: $searchText,
                            isSearching: $isSearching
                        )
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
    @State private var filteredRecipes: [String: [Recipe]] = [:]
    
    private let primaryColor = Color(hex: "00AA00")

    private func updateFilteredRecipes() {
        let categoryFiltered = selectedCategory == nil
            ? dataManager.recipes
            : dataManager.recipes.filter { $0.category == selectedCategory }
        
        let filtered = searchText.isEmpty ? categoryFiltered :
            categoryFiltered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.category.localizedCaseInsensitiveContains(searchText) ||
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        
        var groups = [String: [Recipe]]()
        for recipe in filtered {
            let key = String(recipe.name.prefix(1).uppercased())
            groups[key, default: []].append(recipe)
        }
        for key in groups.keys {
            groups[key]?.sort(by: { $0.name < $1.name })
        }
        filteredRecipes = groups
    }
    
    var body: some View {
        VStack {
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button {
                        selectedCategory = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("All")
                            .fontWeight(.bold)
                            .padding()
                            .background(selectedCategory == nil ? primaryColor : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Show all recipes")
                    .accessibilityHint("Displays recipes from all categories")
                    
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(category)
                                .fontWeight(.bold)
                                .padding()
                                .background(selectedCategory == category ? primaryColor : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel("Show \(category) recipes")
                        .accessibilityHint("Filters recipes to show only \(category) category")
                    }
                }
                .padding(.horizontal)
            }
            
            // Recipe list
            List {
                // Craftify Picks Section
                if !recommendedRecipes.isEmpty && !isSearching {
                    Section(header:
                        CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                            withAnimation { isCraftifyPicksExpanded.toggle() }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    ) {
                        if isCraftifyPicksExpanded {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recommendedRecipes, id: \.name) { recipe in
                                        NavigationLink {
                                            RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                        } label: {
                                            VStack {
                                                Image(recipe.image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 90, height: 90)
                                                    .padding(4)
                                                    .accessibilityLabel("Image of \(recipe.name)")
                                                    .accessibilityHidden(false)
                                                Text(recipe.name)
                                                    .font(.caption)
                                                    .bold()
                                                    .lineLimit(1)
                                                    .frame(width: 90)
                                            }
                                            .padding()
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(12)
                                            .onTapGesture {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Alphabetical sections
                ForEach(filteredRecipes.keys.sorted(), id: \.self) { letter in
                    Section(header:
                        Text(letter)
                            .font(.headline)
                            .bold()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    ) {
                        ForEach(filteredRecipes[letter] ?? [], id: \.name) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                            } label: {
                                HStack {
                                    Image(recipe.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .padding(4)
                                        .accessibilityLabel("Image of \(recipe.name)")
                                        .accessibilityHidden(false)
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
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
                updateFilteredRecipes()
            }
            .task(id: "\(searchText)\(selectedCategory ?? "")") {
                updateFilteredRecipes()
            }
        }
        .navigationTitle("Craftify")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - CraftifyPicksHeader
struct CraftifyPicksHeader: View {
    var isExpanded: Bool
    var toggle: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel(isExpanded ? "Collapse Craftify Picks" : "Expand Craftify Picks")
            .accessibilityHint("Toggles the visibility of recommended recipes")
            
            Text("Craftify Picks")
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
