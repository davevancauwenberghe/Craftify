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
    @AppStorage("hasSeenWelcomeView") private var hasSeenWelcomeView: Bool = false
    
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var isLoading = true
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    // Restore default translucent tab bar appearance
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $navigationPath) {
                    ZStack {
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(Color(hex: "00AA00"))
                                    .scaleEffect(1.5)
                                Text("Loading recipes from Cloud...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Loading recipes from CloudKit")
                            .accessibilityHint("Please wait while Minecraft recipes are fetched")
                        } else {
                            CategoryView(
                                selectedTab: $selectedTab,
                                navigationPath: $navigationPath,
                                searchText: $searchText,
                                feedbackGenerator: feedbackGenerator
                            )
                        }
                    }
                    .navigationTitle("Craftify")
                    .navigationBarTitleDisplayMode(.large)
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
            
            // Welcome view overlay
            if !hasSeenWelcomeView {
                WelcomeView(hasSeenWelcomeView: $hasSeenWelcomeView)
                    .transition(.scale)
            }
        }
        .task {
            if dataManager.recipes.isEmpty {
                await dataManager.loadDataAsync()
            }
            dataManager.syncFavorites()
            isLoading = false
        }
        .onAppear {
            feedbackGenerator.prepare()
        }
    }
}

// MARK: - WelcomeView
struct WelcomeView: View {
    @Binding var hasSeenWelcomeView: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { /* Prevent background taps */ }
            
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2")
                    .font(.largeTitle)
                    .foregroundColor(Color(hex: "00AA00"))
                    .padding(.top, 16)
                
                Text("Welcome to Craftify!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Thank you for testing Craftify! More recipes will be added soon.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Button(action: {
                    feedbackGenerator.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        hasSeenWelcomeView = true
                    }
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            ZStack {
                                Color(UIColor.systemGray5)
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "00AA00"), lineWidth: 2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(
                                color: colorScheme == .light ? .black.opacity(0.15) : .black.opacity(0.3),
                                radius: colorScheme == .light ? 6 : 8
                            )
                        )
                }
                .accessibilityLabel("Get Started")
                .accessibilityHint("Dismiss the welcome message")
                .padding(.bottom, 24)
            }
            .frame(width: 300)
            .background(
                ZStack {
                    Color(UIColor.systemGray5)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "00AA00"), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: colorScheme == .light ? .black.opacity(0.15) : .black.opacity(0.3),
                    radius: colorScheme == .light ? 6 : 8
                )
            )
            .padding(.horizontal, 32)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hasSeenWelcomeView)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to Craftify, thank you for testing Craftify! More recipes will be added soon.")
        .accessibilityHint("Tap Get Started to dismiss the welcome message")
        .onAppear {
            feedbackGenerator.prepare()
        }
    }
}

// MARK: - CategoryView
struct CategoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath
    @Binding var searchText: String
    @State private var selectedCategory: String? = nil
    @State private var recommendedRecipes: [Recipe] = []
    @State private var isCraftifyPicksExpanded = true
    let feedbackGenerator: UIImpactFeedbackGenerator

    // Group recipes by the first letter
    var sortedRecipes: [String: [Recipe]] {
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
            let key = String(recipe.name.prefix(1))
            groups[key, default: []].append(recipe)
        }
        for key in groups.keys {
            groups[key]?.sort(by: { $0.name < $1.name })
        }
        return groups
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "00AA00"))
                    .font(.body)
                TextField("Search recipes", text: $searchText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color(UIColor.systemGray5)
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "00AA00"), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: colorScheme == .light ? .black.opacity(0.15) : .black.opacity(0.3),
                    radius: colorScheme == .light ? 6 : 8
                )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityLabel("Search recipes")
            .accessibilityHint("Enter text to filter recipes by name, category, or ingredients")
            
            // Categories horizontal scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: { selectedCategory = nil }) {
                        Text("All")
                            .fontWeight(.bold)
                            .padding()
                            .background(selectedCategory == nil ? Color(hex: "00AA00") : Color(UIColor.systemGray5))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Select All category")
                    .accessibilityHint("Shows all recipes")
                    ForEach(dataManager.categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category)
                                .fontWeight(.bold)
                                .padding()
                                .background(selectedCategory == category ? Color(hex: "00AA00") : Color(UIColor.systemGray5))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel("Select \(category) category")
                        .accessibilityHint("Shows recipes in the \(category) category")
                    }
                }
                .padding(.horizontal)
            }
            
            // Recipe list
            List {
                // Craftify Picks Section
                if !recommendedRecipes.isEmpty {
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
                                            .background(Color(UIColor.systemGray5))
                                            .cornerRadius(12)
                                        }
                                        .accessibilityLabel("Recommended: \(recipe.name)")
                                        .accessibilityHint("Tap to view details for \(recipe.name)")
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } header: {
                        CraftifyPicksHeader(isExpanded: isCraftifyPicksExpanded, toggle: {
                            withAnimation {
                                isCraftifyPicksExpanded.toggle()
                            }
                        })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // Recipe List Sections
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
                                // Use the same recipe cell UI as in FavoritesView
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
                                    feedbackGenerator.impactOccurred()
                                }
                            )
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .accessibilityLabel("Recipe: \(recipe.name), Category: \(recipe.category.isEmpty ? "None" : recipe.category)")
                            .accessibilityHint("Tap to view details for \(recipe.name)")
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

// MARK: - CraftifyPicksHeader
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
            .accessibilityLabel(isExpanded ? "Collapse Craftify Picks" : "Expand Craftify Picks")
            .accessibilityHint("Toggles the visibility of recommended recipes")
            Text("Craftify Picks")
                .font(.title3)
                .bold()
            Spacer()
        }
        .padding(.horizontal)
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
