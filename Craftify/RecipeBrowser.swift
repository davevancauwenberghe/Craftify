import SwiftUI

/// Keep the library and detail navigation alive as a window resizes or Duo folds.
/// System split-view columns also stay clear of Duo's reserved hinge region.
struct RecipeBrowser<Library: View>: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedRecipeID: Int?
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var detailPath = NavigationPath()

    var resetID: UUID?
    var onSelect: (Recipe) -> Void = { _ in }
    @ViewBuilder var library: (Int?, @escaping (Recipe) -> Void) -> Library

    private var selectedRecipe: Recipe? {
        dataManager.recipes.first { $0.id == selectedRecipeID }
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            library(selectedRecipeID, select)
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 460)
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let recipe = selectedRecipe {
                        RecipeDetailView(recipe: recipe, navigationPath: $detailPath)
                            .id(recipe.id)
                    } else {
                        ContentUnavailableView(
                            "Choose a Recipe",
                            systemImage: "square.grid.3x3",
                            description: Text("Select a recipe to see its ingredients and crafting layout.")
                        )
                    }
                }
                .navigationDestination(for: Recipe.self) { recipe in
                    RecipeDetailView(recipe: recipe, navigationPath: $detailPath)
                }
                .craftifyPage()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: resetID) { _, _ in
            selectedRecipeID = nil
            detailPath = NavigationPath()
            compactColumn = .sidebar
        }
        .onChange(of: dataManager.recipes) { _, recipes in
            if let selectedRecipeID, !recipes.contains(where: { $0.id == selectedRecipeID }) {
                self.selectedRecipeID = nil
                detailPath = NavigationPath()
                compactColumn = .sidebar
            }
        }
    }

    private func select(_ recipe: Recipe) {
        detailPath = NavigationPath()
        selectedRecipeID = recipe.id
        compactColumn = .detail
        onSelect(recipe)
    }
}
