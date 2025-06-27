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
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack {
            // Solid background so the TabView isn’t transparent
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                RecipesTabView(navigationPath: $navigationPath, accentColorPreference: accentColorPreference)
                    .tabItem {
                        Label("Recipes", systemImage: "square.grid.2x2")
                    }
                    .tag(0)
                    .accessibilityLabel("Recipes tab")
                    .accessibilityHint("View all recipes")

                FavoritesView()
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .tag(1)
                    .accessibilityLabel("Favorites tab")
                    .accessibilityHint("View your favorite recipes")

                MoreView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .tag(2)
                    .accessibilityLabel("More tab")
                    .accessibilityHint("Access additional settings and features")

                RecipeSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(3)
                    .accessibilityLabel("Search tab")
                    .accessibilityHint("Search for recipes")
            }
            .accentColor(Color.userAccentColor)
            .preferredColorScheme(
                colorSchemePreference == "system" ? nil :
                    (colorSchemePreference == "light" ? .light : .dark)
            )
            // Frosted-glass behind the tab bar on iOS 17
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .ignoresSafeArea(edges: .bottom)

            if dataManager.isManualSyncing {
                SyncOverlayView(
                    horizontalSizeClass: horizontalSizeClass,
                    message: "Syncing Recipes…"
                )
                .opacity(1)
                .animation(.easeInOut(duration: 0.3), value: dataManager.isManualSyncing)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UIAccessibility.post(
                notification: .announcement,
                argument: "Selected tab: \(tabName(for: newValue))"
            )
        }
    }

    private func tabName(for tag: Int) -> String {
        switch tag {
        case 0: return "Recipes"
        case 1: return "Favorites"
        case 2: return "More"
        case 3: return "Search"
        default: return "Unknown"
        }
    }
}

// MARK: –––––––––––––––––––––––––––––––––––––––––––––––

struct RecipesTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var navigationPath: NavigationPath
    let accentColorPreference: String

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if dataManager.isLoading && dataManager.recipes.isEmpty {
                    // Inline loading placeholder (no undefined types)
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.userAccentColor)
                            .accessibilityValue("Loading")
                        Text("Loading Recipes…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Loading Recipes")
                    .accessibilityHint("Please wait while the recipes are being loaded")
                } else {
                    CategoryView(
                        navigationPath: $navigationPath,
                        accentColorPreference: accentColorPreference
                    )
                    .navigationTitle("Craftify")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(.visible, for: .navigationBar)
                }
            }
        }
        // Nav‐bar blur stays scoped to this stack
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

struct CategoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var navigationPath: NavigationPath
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let accentColorPreference: String

    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredRecipes: [String: [Recipe]] = [:]

    private func updateFilteredRecipes() {
        let source = selectedCategory == nil
            ? dataManager.recipes
            : dataManager.recipes.filter { $0.category == selectedCategory }

        var groups = [String: [Recipe]]()
        for recipe in source {
            let key = String(recipe.name.prefix(1)).uppercased()
            groups[key, default: []].append(recipe)
        }
        for key in groups.keys {
            groups[key]?.sort { $0.name < $1.name }
        }
        filteredRecipes = groups
    }

    var body: some View {
        VStack(spacing: 0) {
            CategoryFilterBar(
                selectedCategory: $selectedCategory,
                categories: dataManager.categories,
                horizontalSizeClass: horizontalSizeClass
            )

            RecipeListView(
                recommendedRecipes: $recommendedRecipes,
                isCraftifyPicksExpanded: $isCraftifyPicksExpanded,
                filteredRecipes: filteredRecipes,
                navigationPath: $navigationPath,
                horizontalSizeClass: horizontalSizeClass,
                accentColorPreference: accentColorPreference
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

struct CategoryFilterBar: View {
    @Binding var selectedCategory: String?
    let categories: [String]
    let horizontalSizeClass: UserInterfaceSizeClass?
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"

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
                        .background(selectedCategory == nil ? Color.userAccentColor : Color.gray.opacity(0.2))
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
                            .background(selectedCategory == category ? Color.userAccentColor : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Show \(category) recipes")
                    .accessibilityHint("Filters recipes to show only \(category) category")
                }
            }
            .id(accentColorPreference)
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
    }
}

struct RecipeListView: View {
    @Binding var recommendedRecipes: [Recipe]
    @Binding var isCraftifyPicksExpanded: Bool
    let filteredRecipes: [String: [Recipe]]
    @Binding var navigationPath: NavigationPath
    let horizontalSizeClass: UserInterfaceSizeClass?
    let accentColorPreference: String

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
                        CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded, accentColorPreference: accentColorPreference) {
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
        .id(accentColorPreference)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
    }
}

struct RecipeCell: View {
    let recipe: Recipe
    let isCraftifyPick: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack(spacing: 12) {
            Image(recipe.image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: isCraftifyPick
                        ? (horizontalSizeClass == .regular ? 96 : 72)
                        : (horizontalSizeClass == .regular ? 80 : 64),
                    height: isCraftifyPick
                        ? (horizontalSizeClass == .regular ? 96 : 72)
                        : (horizontalSizeClass == .regular ? 80 : 64)
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
                colors: [Color.userAccentColor.opacity(0.05), Color.gray.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    Color.userAccentColor.opacity(0.3),
                    style: isCraftifyPick
                        ? StrokeStyle(lineWidth: 1)
                        : StrokeStyle(lineWidth: 1, dash: [4, 4])
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
    var accentColorPreference: String
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
