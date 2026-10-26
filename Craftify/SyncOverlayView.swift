import SwiftUI

/// Syncing keeps downloaded recipes usable while the refresh runs.
struct SyncStatusBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Updating recipes and images…").font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Updating recipes and images. Your recipe book is still available.")
    }
}

/// A system sheet provides fold avoidance and VoiceOver focus containment.
struct NewRecipesOverlayView: View {
    let recipes: [Recipe]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingRecipes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CraftifySectionHeader(
                        title: recipes.count == 1 ? "A New Recipe Arrived" : "\(recipes.count) New Recipes Arrived",
                        detail: "Added since your last successful recipe sync.",
                        symbol: "sparkles"
                    )

                    if showingRecipes {
                        ForEach(recipes) { recipe in
                            HStack(spacing: 12) {
                                CraftImage(key: recipe.image)
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(recipe.name).font(.headline)
                                    Text(recipe.category).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } else {
                        Text("Fresh crafting ideas are ready in your recipe book.")
                            .foregroundStyle(.secondary)
                        Button("Review New Recipes", systemImage: "list.bullet") {
                            showingRecipes = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button("Explore Recipes", systemImage: "hammer.fill") {
                        onDismiss()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
            .navigationTitle("New Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .craftifyPage()
        }
    }
}
