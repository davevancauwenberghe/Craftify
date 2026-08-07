//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cooldownTask: Task<Void, Never>?
    @State private var remainingCooldownTime = 0

    private var dashboardColumns: [GridItem] {
        CraftifyLayout.adaptiveColumns(
            minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 260,
            maximum: 420,
            spacing: 14,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private var syncDetail: String {
        guard let date = dataManager.lastUpdated else { return dataManager.syncStatus }
        return "Last synced \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    CraftifyHero(
                        eyebrow: "Craftify Toolkit",
                        title: "More Ways to Craft",
                        detail: "Keep your recipe book current, find useful commands, personalize the app, and get help when you need it.",
                        symbol: "hammer.circle.fill"
                    )

                    syncCard

                    CraftifySectionHeader(
                        title: "Tools & Help",
                        detail: "Useful extras for Craftify and your Minecraft world."
                    )

                    LazyVGrid(columns: dashboardColumns, spacing: 14) {
                        destination(
                            "Report an Issue",
                            detail: "Request a missing recipe or flag an error.",
                            systemImage: "exclamationmark.bubble.fill"
                        ) { ReportRecipeView() }

                        destination(
                            "Console Commands",
                            detail: "Browse commands for Bedrock and Java Edition.",
                            systemImage: "terminal.fill"
                        ) { CommandsView() }

                        destination(
                            "App Appearance",
                            detail: "Choose your color, appearance, and app icon.",
                            systemImage: "paintpalette.fill"
                        ) { AppAppearanceView() }

                        destination(
                            "About Craftify",
                            detail: "Release notes, support, privacy, and credits.",
                            systemImage: "info.circle.fill"
                        ) { AboutView() }

                        Button {
                            HapticFeedback.impact(.light)
                            NotificationCenter.default.post(name: .showOnboarding, object: nil)
                        } label: {
                            dashboardTile(
                                title: "Getting Started",
                                detail: "Revisit the guided tour of Craftify.",
                                systemImage: "lightbulb.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Craftify’s introductory guide")
                    }
                }
                .craftifyContentWidth()
                .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .craftifyPage()
            .alert("Unable to Sync", isPresented: errorBinding) {
                Button("OK", role: .cancel) { dataManager.errorMessage = nil }
            } message: {
                Text(dataManager.errorMessage ?? "Please try again.")
            }
            .onAppear { dataManager.syncRecentSearches() }
            .onDisappear { stopCooldown() }
        }
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                CraftifyIconTile(
                    symbol: dataManager.isConnected ? "icloud.and.arrow.down.fill" : "icloud.slash.fill",
                    size: 48
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipe Book Sync")
                        .font(.title3.bold())
                    Text("Download new recipes and image updates for reliable offline access.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 9) { syncPills }
                VStack(alignment: .leading, spacing: 9) { syncPills }
            }

            Text(syncDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: syncRecipes) {
                Label(
                    dataManager.isLoading ? "Syncing Recipes & Images…" : "Sync Recipes & Images",
                    systemImage: dataManager.isLoading ? "hourglass" : "arrow.clockwise"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .craftifyButtonBorder(cornerRadius: 16)
            .disabled(dataManager.isLoading || !dataManager.isConnected || remainingCooldownTime > 0)
            .accessibilityHint(syncHint)

            if remainingCooldownTime > 0 {
                Label(
                    "Sync is available again in \(remainingCooldownTime) second\(remainingCooldownTime == 1 ? "" : "s").",
                    systemImage: "timer"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            } else if !dataManager.isConnected {
                Label(
                    "You’re offline. Your downloaded recipe book remains available.",
                    systemImage: "wifi.slash"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
        .padding(18)
        .craftifyCard(cornerRadius: 24)
    }

    @ViewBuilder
    private var syncPills: some View {
        CraftifyStatusPill(
            title: dataManager.isConnected ? "Online" : "Offline",
            symbol: dataManager.isConnected ? "wifi" : "wifi.slash",
            tint: dataManager.isConnected ? .green : .red
        )
        CraftifyStatusPill(
            title: "\(dataManager.recipes.count.formatted()) recipes",
            symbol: "book.closed.fill"
        )
    }

    private var syncHint: String {
        if !dataManager.isConnected { return "Unavailable while offline" }
        if remainingCooldownTime > 0 { return "Available in \(remainingCooldownTime) seconds" }
        return "Fetches the latest Minecraft recipes and images"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { dataManager.errorMessage != nil },
            set: { if !$0 { dataManager.errorMessage = nil } }
        )
    }

    private func destination<Destination: View>(
        _ title: String,
        detail: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            dashboardTile(title: title, detail: detail, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title)")
    }

    private func dashboardTile(title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            CraftifyIconTile(symbol: systemImage, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .craftifyCard(cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func syncRecipes() {
        guard dataManager.isConnected, !dataManager.isLoading, remainingCooldownTime == 0 else { return }
        HapticFeedback.impact(.light)
        dataManager.fetchRecipes(isManual: true) {
            Task { @MainActor in
                if dataManager.isRecipeFetchOnCooldown() { beginCooldown() }
            }
        }
    }

    private func beginCooldown() {
        let lastFetch = dataManager.lastRecipeFetch ?? .distantPast
        remainingCooldownTime = max(0, 30 - Int(Date().timeIntervalSince(lastFetch)))
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor in
            while remainingCooldownTime > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remainingCooldownTime -= 1
            }
            cooldownTask = nil
        }
    }

    private func stopCooldown() {
        cooldownTask?.cancel()
        cooldownTask = nil
        remainingCooldownTime = 0
    }
}

struct AboutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.craftifyAccentColor) private var accent

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) • Build \(build)"
    }

    private var linkColumns: [GridItem] {
        if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        aboutIdentityVertical
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 22) {
                                appIcon
                                aboutIdentityCopy(alignment: .leading)
                            }
                            aboutIdentityVertical
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .craftifyCard(cornerRadius: 26)

                CraftifySectionHeader(title: "Information")
                LazyVGrid(columns: linkColumns, spacing: 14) {
                    aboutDestination("Release Notes", detail: "See what changed in every Craftify build.", symbol: "sparkles") {
                        ReleaseNotesView()
                    }
                    aboutDestination("Support & Privacy", detail: "Contact support or manage your data.", symbol: "hand.raised.fill") {
                        SupportView()
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    CraftifySectionHeader(title: "Acknowledgements", symbol: "heart.fill")
                    Link(destination: URL(string: "https://minecraft.wiki/")!) {
                        Label("Visit Minecraft Wiki", systemImage: "arrow.up.right.square")
                            .font(.headline)
                    }
                    Text("Thank you to the Minecraft Wiki contributors for the recipe knowledge and thumbnails that help power Craftify.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .craftifyCard(cornerRadius: 22)

                Label(
                    "Craftify for Minecraft is an independent app and is not approved by or associated with Mojang or Microsoft.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(16)
                .craftifyCard(cornerRadius: 18)
            }
            .craftifyContentWidth()
            .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.large)
        .craftifyPage()
    }

    private var appIcon: some View {
        Image("AppIconPreview")
            .resizable()
            .scaledToFit()
            .frame(width: horizontalSizeClass == .regular ? 112 : 94)
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .shadow(color: accent.opacity(0.20), radius: 16, y: 8)
            .accessibilityLabel("Craftify app icon")
    }

    private var aboutIdentityVertical: some View {
        VStack(spacing: 14) {
            appIcon
            aboutIdentityCopy(alignment: .center)
        }
    }

    private func aboutIdentityCopy(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 7) {
            Text("Craftify for Minecraft")
                .font(.largeTitle.bold())
                .multilineTextAlignment(alignment)
            Text(appVersion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            Text("A focused crafting companion for discovering recipes and planning projects in synced chests.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private func aboutDestination<Destination: View>(
        _ title: String,
        detail: String,
        symbol: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                CraftifyIconTile(symbol: symbol, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .craftifyCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title)")
    }
}
