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

    var body: some View {
        CraftifyOverlayCard(
            horizontalSizeClass: horizontalSizeClass,
            title: message,
            detail: "Gathering the latest recipes from the cloud",
            symbol: "book.closed.fill",
            badgeSymbol: "icloud.fill"
        ) {
            ProgressView()
                .tint(Color.userAccentColor)
                .controlSize(.small)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Gathering the latest recipes from the cloud")
        .accessibilityHint("Please wait. This view closes automatically when syncing is complete.")
    }
}

struct NewRecipesOverlayView: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    let recipeCount: Int
    let onDismiss: () -> Void

    private var title: String {
        recipeCount == 1 ? "A New Recipe Arrived!" : "\(recipeCount) New Recipes Arrived!"
    }

    private var detail: String {
        recipeCount == 1
            ? "A fresh crafting idea just landed in your recipe book."
            : "Fresh crafting ideas just landed in your recipe book."
    }

    var body: some View {
        CraftifyOverlayCard(
            horizontalSizeClass: horizontalSizeClass,
            title: title,
            detail: detail,
            symbol: "book.closed.fill",
            badgeSymbol: "sparkles"
        ) {
            Button(action: onDismiss) {
                Label("Explore Recipes", systemImage: "hammer.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.userAccentColor)
            .accessibilityHint("Dismisses this message and opens your recipe library")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct CraftifyOverlayCard<Footer: View>: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    let title: String
    let detail: String
    let symbol: String
    let badgeSymbol: String
    let footer: Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    init(
        horizontalSizeClass: UserInterfaceSizeClass?,
        title: String,
        detail: String,
        symbol: String,
        badgeSymbol: String,
        @ViewBuilder footer: () -> Footer
    ) {
        self.horizontalSizeClass = horizontalSizeClass
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.badgeSymbol = badgeSymbol
        self.footer = footer()
    }

    private var cardWidth: CGFloat {
        horizontalSizeClass == .regular ? 420 : 330
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                illustration

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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.userAccentColor.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .accessibilityAddTraits(.isModal)
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(Color.userAccentColor.opacity(0.10))
                .frame(width: 108, height: 108)
                .scaleEffect(isAnimating && !reduceMotion ? 1.08 : 0.94)
                .opacity(isAnimating && !reduceMotion ? 0.55 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.userAccentColor.gradient)
                .frame(width: 76, height: 76)
                .shadow(color: Color.userAccentColor.opacity(0.24), radius: 14, y: 7)

            Image(systemName: symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)

            Image(systemName: badgeSymbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.userAccentColor)
                .padding(7)
                .background(.regularMaterial, in: Circle())
                .offset(x: 35, y: 35)
                .scaleEffect(isAnimating && !reduceMotion ? 1 : 0.88)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: isAnimating)
        }
        .frame(width: 116, height: 116)
        .accessibilityHidden(true)
    }
}
