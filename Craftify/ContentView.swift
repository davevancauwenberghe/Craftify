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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecipesTabView(navigationPath: $navigationPath)
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
                
                RecipeSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(3)
            }
            .preferredColorScheme(
                colorSchemePreference == "system" ? nil :
                (colorSchemePreference == "light" ? .light : .dark)
            )
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onChange(of: selectedTab) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            // Show onboarding if first launch or manual sync
            if showOnboarding || dataManager.isManualSyncing {
                OnboardingView(
                    title: showOnboarding ? "Welcome to Craftify!" : "Syncing Your Recipes…",
                    message: "Fetching your recipes from the cloud…",
                    isLoading: dataManager.isLoading,
                    errorMessage: dataManager.errorMessage,
                    isFirstLaunch: showOnboarding,
                    onDismiss: {
                        hasCompletedOnboarding = true
                        showOnboarding = false
                    },
                    onRetry: {
                        dataManager.loadData(isManual: !showOnboarding) {
                            dataManager.syncFavorites()
                        }
                    },
                    horizontalSizeClass: horizontalSizeClass
                )
                .opacity(showOnboarding || dataManager.isManualSyncing ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showOnboarding || dataManager.isManualSyncing)
            }
        }
        .onAppear {
            // Check if this is the first launch
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: dataManager.isLoading) { _, newValue in
            // For manual syncs, dismiss automatically when loading completes
            if !newValue && dataManager.isManualSyncing {
                // View updates are handled reactively
            }
        }
    }
}

struct RecipesTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            CategoryView(navigationPath: $navigationPath)
                .navigationTitle("Craftify")
                .navigationBarTitleDisplayMode(.large)
                .toolbar(.visible, for: .navigationBar)
                .task {
                    // Always load data to ensure we have the latest recipes
                    await dataManager.loadDataAsync(isManual: false)
                    dataManager.syncFavorites()
                }
        }
    }
}

struct CategoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var navigationPath: NavigationPath
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredRecipes: [String: [Recipe]] = [:]
    
    private let primaryColor = Color(hex: "00AA00")
    
    private func updateFilteredRecipes() {
        let categoryFiltered = selectedCategory == nil
            ? dataManager.recipes
            : dataManager.recipes.filter { $0.category == selectedCategory }
        
        var groups = [String: [Recipe]]()
        for recipe in categoryFiltered {
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
            CategoryFilterBar(
                selectedCategory: $selectedCategory,
                categories: dataManager.categories,
                primaryColor: primaryColor,
                horizontalSizeClass: horizontalSizeClass
            )
            
            RecipeListView(
                recommendedRecipes: $recommendedRecipes,
                isCraftifyPicksExpanded: $isCraftifyPicksExpanded,
                filteredRecipes: filteredRecipes,
                navigationPath: $navigationPath,
                primaryColor: primaryColor,
                horizontalSizeClass: horizontalSizeClass
            )
        }
        .navigationTitle("Craftify")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
            updateFilteredRecipes()
        }
        .onChange(of: dataManager.recipes) { _, _ in
            recommendedRecipes = Array(dataManager.recipes.shuffled().prefix(5))
            updateFilteredRecipes()
        }
        .onChange(of: selectedCategory) { _, _ in
            updateFilteredRecipes()
        }
    }
}

// Extracted view for the category filter bar
struct CategoryFilterBar: View {
    @Binding var selectedCategory: String?
    let categories: [String]
    let primaryColor: Color
    let horizontalSizeClass: UserInterfaceSizeClass?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategory = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("All")
                        .fontWeight(.bold)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == nil ? primaryColor : Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .accessibilityLabel("Show all recipes")
                .accessibilityHint("Displays recipes from all categories")
                
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(category)
                            .fontWeight(.bold)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? primaryColor : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Show \(category) recipes")
                    .accessibilityHint("Filters recipes to show only \(category) category")
                }
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
    }
}

// Extracted view for the recipe list
struct RecipeListView: View {
    @Binding var recommendedRecipes: [Recipe]
    @Binding var isCraftifyPicksExpanded: Bool
    let filteredRecipes: [String: [Recipe]]
    @Binding var navigationPath: NavigationPath
    let primaryColor: Color
    let horizontalSizeClass: UserInterfaceSizeClass?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !recommendedRecipes.isEmpty {
                    Section {
                        if isCraftifyPicksExpanded {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 8) {
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
                                .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
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
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
    }
}

struct RecipeCell: View {
    let recipe: Recipe
    let isCraftifyPick: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private let primaryColor = Color(hex: "00AA00")
    
    var body: some View {
        HStack(spacing: 12) {
            Image(recipe.image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: isCraftifyPick ? (horizontalSizeClass == .regular ? 96 : 72) : (horizontalSizeClass == .regular ? 80 : 64),
                    height: isCraftifyPick ? (horizontalSizeClass == .regular ? 96 : 72) : (horizontalSizeClass == .regular ? 80 : 64)
                )
                .cornerRadius(8)
                .padding(4)
                .accessibilityLabel("Image of \(recipe.name)")
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !recipe.category.isEmpty {
                    Text(recipe.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.trailing, horizontalSizeClass == .regular ? 12 : 8)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [primaryColor.opacity(0.05), Color.gray.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    primaryColor.opacity(0.3),
                    style: isCraftifyPick ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(recipe.category.isEmpty ? "recipe" : "\(recipe.category) recipe")")
        .accessibilityHint("Navigates to the detailed view of \(recipe.name)")
    }
}

struct CraftifyPicksHeader: View {
    var isExpanded: Bool
    var toggle: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .contentShape(Rectangle())
            .accessibilityLabel(isExpanded ? "Collapse Craftify Picks" : "Expand Craftify Picks")
            .accessibilityHint("Toggles the visibility of recommended recipes")
            
            Text("Craftify Picks")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .frame(height: horizontalSizeClass == .regular ? 44 : 36)
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
