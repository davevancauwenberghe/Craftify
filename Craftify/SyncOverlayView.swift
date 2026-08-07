//
//  SyncOverlayView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 19/05/2025.
//

import SwiftUI

struct SyncOverlayView: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    let message: String
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        CraftifyOverlayCard(
            horizontalSizeClass: horizontalSizeClass,
            title: message,
            detail: "Gathering the latest recipes from the cloud",
            symbol: "book.closed.fill",
            badgeSymbol: "icloud.fill"
        ) {
            ProgressView()
                .tint(accent)
                .controlSize(.small)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Gathering the latest recipes from the cloud")
        .accessibilityHint("Please wait. This view closes automatically when syncing is complete.")
    }
}

struct NewRecipesOverlayView: View {
    private enum Page: Equatable {
        case summary
        case recipeList
    }

    let horizontalSizeClass: UserInterfaceSizeClass?
    let recipes: [Recipe]
    let onDismiss: () -> Void

    @State private var page: Page = .summary
    @Environment(\.craftifyAccentColor) private var accent

    private var recipeCount: Int {
        recipes.count
    }

    private var title: String {
        switch page {
        case .summary:
            recipeCount == 1
                ? "A New Recipe Arrived!"
                : "\(recipeCount) New Recipes Arrived!"
        case .recipeList:
            recipeCount == 1 ? "Meet the New Recipe" : "Meet the New Recipes"
        }
    }

    private var detail: String {
        switch page {
        case .summary:
            recipeCount == 1
                ? "A fresh crafting idea just landed in your recipe book."
                : "Fresh crafting ideas just landed in your recipe book."
        case .recipeList:
            "Added since your last successful recipe sync."
        }
    }

    private var reviewButtonTitle: String {
        recipeCount == 1 ? "Review New Recipe" : "Review New Recipes"
    }

    var body: some View {
        CraftifyOverlayCard(
            horizontalSizeClass: horizontalSizeClass,
            title: title,
            detail: detail,
            symbol: "book.closed.fill",
            badgeSymbol: page == .summary ? "sparkles" : "list.bullet",
            showsIllustration: page == .summary
        ) {
            switch page {
            case .summary:
                summaryActions
            case .recipeList:
                recipeListContent
            }
        }
        .animation(.easeInOut(duration: 0.25), value: page)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var summaryActions: some View {
        VStack(spacing: 10) {
            exploreButton

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    page = .recipeList
                }
            } label: {
                Label(reviewButtonTitle, systemImage: "list.bullet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(accent)
            .accessibilityHint("Shows the names and record IDs of the newly added recipes")
        }
    }

    private var recipeListContent: some View {
        VStack(spacing: 12) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recipes) { recipe in
                        NewRecipeAnnouncementRow(recipe: recipe)

                        if recipe.id != recipes.last?.id {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
            .background(
                Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .accessibilityLabel("New recipes")

            exploreButton

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    page = .summary
                }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(accent)
            .accessibilityHint("Returns to the new recipe summary")
        }
    }

    private var exploreButton: some View {
        Button(action: onDismiss) {
            Label("Explore Recipes", systemImage: "hammer.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(accent)
        .accessibilityHint("Dismisses this message and opens your recipe library")
    }
}

private struct NewRecipeAnnouncementRow: View {
    let recipe: Recipe

    private var metadata: String {
        recipe.category.isEmpty
            ? "Record ID \(recipe.id)"
            : "Record ID \(recipe.id) • \(recipe.category)"
    }

    var body: some View {
        HStack(spacing: 12) {
            CraftImage(key: recipe.image)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(metadata)")
    }
}

private struct CraftifyOverlayCard<Footer: View>: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    let title: String
    let detail: String
    let symbol: String
    let badgeSymbol: String
    let showsIllustration: Bool
    let footer: Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.craftifyAccentColor) private var accent
    @State private var isAnimating = false

    init(
        horizontalSizeClass: UserInterfaceSizeClass?,
        title: String,
        detail: String,
        symbol: String,
        badgeSymbol: String,
        showsIllustration: Bool = true,
        @ViewBuilder footer: () -> Footer
    ) {
        self.horizontalSizeClass = horizontalSizeClass
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.badgeSymbol = badgeSymbol
        self.showsIllustration = showsIllustration
        self.footer = footer()
    }

    private var cardWidth: CGFloat {
        horizontalSizeClass == .regular ? 440 : 350
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(reduceTransparency ? 0.52 : 0.34)
                    .ignoresSafeArea()

                ScrollView {
                    VStack {
                        Spacer(minLength: 20)

                        VStack(spacing: 20) {
                            if showsIllustration {
                                illustration
                            }

                            VStack(spacing: 7) {
                                Text(title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)

                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            footer
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 30)
                        .frame(maxWidth: cardWidth)
                        .craftifyFloatingSurface(cornerRadius: 28)
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 20)
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .accessibilityAddTraits(.isModal)
    }

    private var illustration: some View {
        ZStack {
            CraftifyIconTile(symbol: symbol, size: 82)

            Image(systemName: badgeSymbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(accent)
                .padding(7)
                .background(.regularMaterial, in: Circle())
                .offset(x: 37, y: 37)
                .scaleEffect(isAnimating && !reduceMotion ? 1 : 0.88)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: isAnimating)
        }
        .frame(width: 116, height: 116)
        .accessibilityHidden(true)
    }
}
