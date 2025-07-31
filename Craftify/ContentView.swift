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

// Applies the frosted-glass only on iOS 17 for the tab bar
private struct iOS17TabBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            return content
        } else {
            return content.toolbarBackground(.ultraThinMaterial, for: .tabBar)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack {
            // 1) solid base so the TabView never floats transparent
            Color(.systemBackground)
                .ignoresSafeArea()

            // 2) your TabView
            TabView(selection: $selectedTab) {
                RecipesTabView(
                    navigationPath: $navigationPath,
                    accentColorPreference: accentColorPreference
                )
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
                        // on iPadOS 18+, show icon-only
                        if UIDevice.current.userInterfaceIdiom == .pad,
                           #available(iOS 18.0, *) {
                            Image(systemName: "magnifyingglass")
                        } else {
                            Label("Search", systemImage: "magnifyingglass")
                        }
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
            .ignoresSafeArea(edges: .bottom)

            // 3) manual-sync overlay
            if dataManager.isManualSyncing {
                SyncOverlayView(
                    horizontalSizeClass: horizontalSizeClass,
                    message: "Syncing Recipes…"
                )
                .opacity(1)
                .animation(.easeInOut(duration: 0.3), value: dataManager.isManualSyncing)
            }
        }
        // ────────────────────────────────────────────────────────────
        // 4) nav-bar material on all OS, tab-bar only on iOS 17
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .modifier(iOS17TabBarBackground())
        // ────────────────────────────────────────────────────────────
        .onChange(of: selectedTab) { _, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UIAccessibility.post(
                notification: .announcement,
                argument: "Selected tab: \(tabName(for: newValue))"
            )
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
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

// MARK: ––––––––––––––––––––––––––––––––––––––––––––––––––

struct RecipesTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var navigationPath: NavigationPath
    let accentColorPreference: String

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if dataManager.isLoading && dataManager.recipes.isEmpty {
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
                }
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
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
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct CategoryFilterBar: View {
    @Binding var selectedCategory: String?
    let categories: [String]
    let horizontalSizeClass: UserInterfaceSizeClass?
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @ScaledMetric(relativeTo: .body) private var buttonPaddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var buttonPaddingVertical: CGFloat = 8

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategory = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("All")
                        .font(.body)
                        .fontWeight(.bold)
                        .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
                        .padding(.vertical, buttonPaddingVertical)
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
                            .font(.body)
                            .fontWeight(.bold)
                            .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
                            .padding(.vertical, buttonPaddingVertical)
                            .background(selectedCategory == category ? Color.userAccentColor : Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Show \(category) recipes")
                    .accessibilityHint("Filters recipes to show only \(category) category")
                }
            }
            .id(accentColorPreference)
            .padding(.horizontal, horizontalSizeClass == .regular ? buttonPaddingHorizontal * 1.5 : buttonPaddingHorizontal)
            .padding(.vertical, buttonPaddingVertical)
        }
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct RecipeListView: View {
    @Binding var recommendedRecipes: [Recipe]
    @Binding var isCraftifyPicksExpanded: Bool
    let filteredRecipes: [String: [Recipe]]
    @Binding var navigationPath: NavigationPath
    let horizontalSizeClass: UserInterfaceSizeClass?
    let accentColorPreference: String
    @ScaledMetric(relativeTo: .body) private var gridSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !recommendedRecipes.isEmpty {
                    Section {
                        if isCraftifyPicksExpanded {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: gridSpacing) {
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
                                .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
                                .padding(.vertical, paddingVertical)
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
                        if horizontalSizeClass == .regular {
                            // iPad: Two-column grid
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: gridSpacing),
                                    GridItem(.flexible(), spacing: gridSpacing)
                                ],
                                alignment: .leading,
                                spacing: gridSpacing
                            ) {
                                ForEach(filteredRecipes[letter] ?? [], id: \.name) { recipe in
                                    NavigationLink {
                                        RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                    } label: {
                                        RecipeCell(recipe: recipe, isCraftifyPick: false)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                }
                            }
                            .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
                        } else {
                            // iPhone: Single-column stack
                            ForEach(filteredRecipes[letter] ?? [], id: \.name) { recipe in
                                NavigationLink {
                                    RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                } label: {
                                    RecipeCell(recipe: recipe, isCraftifyPick: false)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                    } header: {
                        Text(letter)
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
                            .padding(.vertical, paddingVertical)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                    }
                }
            }
        }
        .id(accentColorPreference)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct RecipeCell: View {
    let recipe: Recipe
    let isCraftifyPick: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var imageSizeRegular: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var imageSizeCompact: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var imageSizePickRegular: CGFloat = 96
    @ScaledMetric(relativeTo: .body) private var imageSizePickCompact: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 10

    var body: some View {
        HStack(spacing: 12) {
            Image(recipe.image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: isCraftifyPick
                        ? (horizontalSizeClass == .regular ? imageSizePickRegular : imageSizePickCompact)
                        : (horizontalSizeClass == .regular ? imageSizeRegular : imageSizeCompact),
                    height: isCraftifyPick
                        ? (horizontalSizeClass == .regular ? imageSizePickRegular : imageSizePickCompact)
                        : (horizontalSizeClass == .regular ? imageSizeRegular : imageSizeCompact)
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
                .padding(.trailing, horizontalSizeClass == .regular ? paddingHorizontal * 0.75 : paddingHorizontal * 0.5)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal : paddingHorizontal * 0.75)
        .padding(.vertical, paddingVertical)
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
        .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(recipe.category.isEmpty ? "recipe" : "\(recipe.category) recipe")")
        .accessibilityHint("Navigates to the detailed view of \(recipe.name)")
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

struct CraftifyPicksHeader: View {
    var isExpanded: Bool
    var accentColorPreference: String
    var toggle: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var headerHeightRegular: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var headerHeightCompact: CGFloat = 36

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
        .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.5 : paddingHorizontal)
        .padding(.vertical, paddingVertical)
        .background(Color(.systemBackground))
        .frame(height: horizontalSizeClass == .regular ? headerHeightRegular : headerHeightCompact)
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
