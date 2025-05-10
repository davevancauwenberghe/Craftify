//
//  ContentView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit
import UIKit

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var isSearching = false
    @State private var isLoading = true

    init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().isTranslucent = false
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
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
                .toolbar(.visible, for: .navigationBar)
                .searchable(
                    text: $searchText,
                    isPresented: $isSearchActive,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search recipes"
                )
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
        .onChange(of: isSearchActive) {
            if !isSearchActive {
                searchText = ""
            }
        }
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
        VStack(spacing: 0) {
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("All")
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == nil ? primaryColor : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Show all recipes")
                    .accessibilityHint("Displays recipes from all categories")
                    
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? primaryColor : Color.gray.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel("Show \(category) recipes")
                        .accessibilityHint("Filters recipes to show only \(category) category")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // Recipe list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Craftify Picks Section
                    if !recommendedRecipes.isEmpty && !isSearching {
                        Section {
                            if isCraftifyPicksExpanded {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(recommendedRecipes, id: \.name) { recipe in
                                            NavigationLink {
                                                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                            } label: {
                                                RecipeCell(recipe: recipe, isCraftifyPick: true)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Rectangle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                            }
                        } header: {
                            CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded) {
                                withAnimation { isCraftifyPicksExpanded.toggle() }
                            }
                            .background(Color(.systemBackground))
                        }
                    }

                    // Alphabetical sections
                    ForEach(filteredRecipes.keys.sorted(), id: \.self) { letter in
                        Section {
                            ForEach(filteredRecipes[letter] ?? [], id: \.name) { recipe in
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                } label: {
                                    RecipeCell(recipe: recipe, isCraftifyPick: false)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        } header: {
                            Text(letter)
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                        }
                    }
                }
            }
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
