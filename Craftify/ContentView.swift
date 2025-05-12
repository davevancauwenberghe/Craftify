//
//  ContentView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit

extension Color {
    static let primaryColor = Color(hex: "00AA00")
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.primaryColor.opacity(0.8) : Color.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .overlay {
                #if os(macOS)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.5), lineWidth: configuration.isPressed ? 2 : 0)
                #endif
            }
    }
}

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var isSearching = false
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                TabView(selection: $selectedTab) {
                    NavigationStack(path: $navigationPath) {
                        CategoryView(
                            selectedTab: $selectedTab,
                            navigationPath: $navigationPath,
                            searchText: $searchText,
                            isSearching: $isSearching,
                            geometry: geometry
                        )
                        .navigationTitle("Craftify")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar(.visible, for: .navigationBar)
                        .toolbarBackground(.automatic, for: .navigationBar)
                        .searchable(
                            text: $searchText,
                            isPresented: $isSearchActive,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Search recipes"
                        )
                    }
                    .navigationViewStyle(.stack)
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
                .safeAreaPadding(.bottom, 60)
            }
            .preferredColorScheme(
                colorSchemePreference == "system" ? nil :
                (colorSchemePreference == "light" ? .light : .dark)
            )
            .onChange(of: isSearchActive) { _ in
                if !isSearchActive {
                    searchText = ""
                }
            }
            .onChange(of: selectedTab) { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .task {
                if dataManager.recipes.isEmpty {
                    await dataManager.loadDataAsync()
                }
                dataManager.syncFavorites()
                isLoading = false
            }
            .onAppear {
                print("ContentView bounds: \(UIScreen.main.bounds)")
            }
            .onChange(of: navigationPath) { path in
                print("Navigation path count: \(path.count)")
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
    let geometry: GeometryProxy
    
    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    @State private var isCraftifyPicksExpanded = true
    @State private var filteredRecipes: [String: [Recipe]] = [:]

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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: min(geometry.size.width * 0.02, 8)) {
                    Button {
                        selectedCategory = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("All")
                            .fontWeight(.bold)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Show all recipes")
                    .accessibilityHint("Displays recipes from all categories")
                    
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(category)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel("Show \(category) recipes")
                        .accessibilityHint("Filters recipes to show only \(category) category")
                    }
                }
                .padding(.horizontal, min(geometry.size.width * 0.04, 16))
                .padding(.vertical, min(geometry.size.height * 0.01, 8))
            }
            
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if !recommendedRecipes.isEmpty && !isSearching {
                        Section {
                            if isCraftifyPicksExpanded {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: min(geometry.size.width * 0.02, 8)) {
                                        ForEach(recommendedRecipes, id: \.name) { recipe in
                                            NavigationLink {
                                                RecipeDetailView(recipe: recipe, navigationPath: $navigationPath)
                                            } label: {
                                                RecipeCell(recipe: recipe, isCraftifyPick: true, geometry: geometry)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Rectangle())
                                        }
                                    }
                                    .padding(.horizontal, min(geometry.size.width * 0.04, 16))
                                    .padding(.vertical, min(geometry.size.height * 0.01, 8))
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
                                    RecipeCell(recipe: recipe, isCraftifyPick: false, geometry: geometry)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        } header: {
                            Text(letter)
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal, min(geometry.size.width * 0.04, 16))
                                .padding(.vertical, min(geometry.size.height * 0.01, 8))
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

struct RecipeCell: View {
    let recipe: Recipe
    let isCraftifyPick: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        HStack(spacing: min(geometry.size.width * 0.03, 12)) {
            Image(recipe.image)
                .resizable()
                .scaledToFit()
                .frame(width: isCraftifyPick ? min(geometry.size.width * 0.2, 80) : min(geometry.size.width * 0.18, 72),
                       height: isCraftifyPick ? min(geometry.size.width * 0.2, 80) : min(geometry.size.width * 0.18, 72))
                .cornerRadius(min(geometry.size.width * 0.02, 8))
                .padding(min(geometry.size.width * 0.01, 4))
                .accessibilityLabel("Image of \(recipe.name)")
            
            VStack(alignment: .leading, spacing: min(geometry.size.height * 0.005, 4)) {
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
                .padding(.trailing, min(geometry.size.width * 0.02, 8))
        }
        .padding(.horizontal, min(geometry.size.width * 0.04, 16))
        .padding(.vertical, min(geometry.size.height * 0.015, 10))
        .background(
            LinearGradient(
                colors: [Color.primaryColor.opacity(0.05), Color.gray.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(min(geometry.size.width * 0.025, 10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: min(geometry.size.width * 0.025, 10))
                .stroke(
                    Color.primaryColor.opacity(0.3),
                    style: isCraftifyPick ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
        .padding(.horizontal, min(geometry.size.width * 0.04, 16))
        .padding(.vertical, min(geometry.size.height * 0.005, 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(recipe.category.isEmpty ? "recipe" : "\(recipe.category) recipe")")
        .accessibilityHint("Navigates to the detailed view of \(recipe.name)")
    }
}

struct CraftifyPicksHeader: View {
    var isExpanded: Bool
    var toggle: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: min(geometry.size.width * 0.02, 8)) {
                Button {
                    toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(min(geometry.size.width * 0.02, 8))
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
            .padding(.horizontal, min(geometry.size.width * 0.04, 16))
            .padding(.vertical, min(geometry.size.height * 0.01, 8))
        }
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
