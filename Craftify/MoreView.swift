//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @State private var cooldownTask: Task<Void, Never>?
    @State private var remainingCooldownTime = 0

    private var syncDetail: String {
        guard let date = dataManager.lastUpdated else { return dataManager.syncStatus }
        return "Last synced \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Help & Reference") {
                    destination("Report an Issue", systemImage: "exclamationmark.bubble.fill", hint: "Report a missing recipe or an error") {
                        ReportRecipeView()
                    }
                    destination("Console Commands", systemImage: "terminal.fill", hint: "Browse Minecraft console commands") {
                        CommandsView()
                    }
                }

                Section {
                    destination("About Craftify", systemImage: "info.circle.fill", hint: "View app information, appearance, release notes, support, and privacy") {
                        AboutView()
                    }
                    destination("App Appearance", systemImage: "paintpalette.fill", hint: "Choose the app icon, color, and appearance") {
                        AppAppearanceView()
                    }
                    Button {
                        NotificationCenter.default.post(name: .showOnboarding, object: nil)
                    } label: {
                        accentLabel("Getting Started", systemImage: "lightbulb.fill")
                    }
                    .accessibilityHint("Revisit Craftify's introductory tips")
                } header: {
                    Text("Craftify")
                }

                Section {
                    Button(action: syncRecipes) {
                        Label {
                            Text(dataManager.isLoading ? "Syncing Recipes…" : "Sync Recipes")
                                .foregroundStyle(.primary)
                        } icon: {
                            if dataManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Color.userAccentColor)
                            }
                        }
                    }
                    .disabled(dataManager.isLoading || !dataManager.isConnected || remainingCooldownTime > 0)
                    .accessibilityHint(syncHint)

                    syncStatus
                } header: {
                    Text("Data Sync")
                } footer: {
                    if remainingCooldownTime > 0 {
                        Text("Sync is available again in \(remainingCooldownTime) second\(remainingCooldownTime == 1 ? "" : "s").")
                            .contentTransition(.numericText())
                    } else if !dataManager.isConnected {
                        Text("Connect to the internet to sync recipes. Craftify will keep your existing recipes available offline.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(24)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .tint(Color.userAccentColor)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert("Unable to Sync", isPresented: errorBinding) {
                Button("OK", role: .cancel) { dataManager.errorMessage = nil }
            } message: {
                Text(dataManager.errorMessage ?? "Please try again.")
            }
            .onAppear {
                dataManager.syncFavorites()
                dataManager.syncRecentSearches()
            }
            .onDisappear { stopCooldown() }
        }
    }

    private var syncHint: String {
        if !dataManager.isConnected { return "Unavailable while offline" }
        if remainingCooldownTime > 0 { return "Available in \(remainingCooldownTime) seconds" }
        return "Fetch the latest Minecraft recipes"
    }

    @ViewBuilder
    private var syncStatus: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                connectionStatus
                recipeCountStatus
                syncDetailText
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    connectionStatus
                    recipeCountStatus
                }
                syncDetailText
            }
        }
    }

    private var connectionStatus: some View {
        syncStatusItem(
            dataManager.isConnected ? "Online" : "Offline",
            systemImage: dataManager.isConnected ? "wifi" : "wifi.slash",
            color: dataManager.isConnected ? .green : .red
        )
    }

    private var recipeCountStatus: some View {
        syncStatusItem(
            "\(dataManager.recipes.count.formatted()) recipes",
            systemImage: "book.closed.fill"
        )
    }

    private var syncDetailText: some View {
        Text(syncDetail)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { dataManager.errorMessage != nil },
            set: { if !$0 { dataManager.errorMessage = nil } }
        )
    }

    private func syncStatusItem(_ title: String, systemImage: String, color: Color = .secondary) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func destination<Destination: View>(
        _ title: String,
        systemImage: String,
        hint: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            accentLabel(title, systemImage: systemImage)
        }
        .accessibilityHint(hint)
    }

    private func accentLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.userAccentColor)
        }
    }

    private func syncRecipes() {
        guard dataManager.isConnected, !dataManager.isLoading, remainingCooldownTime == 0 else { return }
        HapticFeedback.impact(.light)
        dataManager.fetchRecipes(isManual: true) {
            Task { @MainActor in
                if dataManager.isRecipeFetchOnCooldown() {
                    beginCooldown()
                }
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
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) • Build \(build)"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image("AppIconPreview")
                        .resizable()
                        .scaledToFit()
                        .frame(width: horizontalSizeClass == .regular ? 104 : 88, height: horizontalSizeClass == .regular ? 104 : 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("Craftify app icon")

                    Text("Craftify for Minecraft")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("A focused companion for finding Minecraft recipes and organizing recipes in synced chests.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }

            Section("Information") {
                NavigationLink(destination: ReleaseNotesView()) {
                    accentLabel("Release Notes", systemImage: "sparkles")
                }
                NavigationLink(destination: SupportView()) {
                    accentLabel("Support & Privacy", systemImage: "hand.raised.fill")
                }
            }

            Section("Acknowledgements") {
                Link(destination: URL(string: "https://minecraft.wiki/")!) {
                    accentLabel("Minecraft Wiki", systemImage: "arrow.up.right.square")
                }
                Text("Thank you to the Minecraft Wiki contributors for the recipe knowledge and thumbnails that help power Craftify.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Craftify for Minecraft is an independent app and is not approved by or associated with Mojang or Microsoft.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .tint(Color.userAccentColor)
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    private func accentLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.userAccentColor)
        }
    }
}
