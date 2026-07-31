import SwiftUI

/// The recipe library's recovery state after its local data has been cleared.
struct EmptyRecipeView: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 16

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.userAccentColor)

            Text("No recipes on this device")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text("Head to More and choose Sync Recipes to fetch the recipe library again.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, padding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(padding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No recipes on this device. Head to More and choose Sync Recipes to fetch the recipe library again.")
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
