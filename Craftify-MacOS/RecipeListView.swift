import SwiftUI
import Combine
import CloudKit

struct RecipeListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isSearching = false
    
    var sortedRecipes: [String: [Recipe]] {
        // Filter recipes based on the search text.
        let filtered = searchText.isEmpty ? dataManager.recipes : dataManager.recipes.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(searchText) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        // Group by the first letter of the recipe name and sort each group.
        return Dictionary(grouping: filtered, by: { String($0.name.prefix(1)) })
            .mapValues { $0.sorted { $0.name < $1.name } }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(sortedRecipes.keys.sorted(), id: \.self) { letter in
                    Section(header: Text(letter)
                                .font(.headline)
                                .bold()
                                .foregroundColor(.primary)
                                .padding(.vertical, 4)) {
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
                                        Text(recipe.category)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .onChange(of: searchText) { _, newValue in
                isSearching = !newValue.isEmpty
            }
            .navigationTitle("Recipes")
        }
    }
}

struct RecipeListView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeListView()
            .environmentObject(DataManager())
    }
}
