//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var dataManager: DataManager
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

                Section("Craftify") {
                    destination("About Craftify", systemImage: "info.circle.fill", hint: "View app information, appearance, release notes, support, and privacy") {
                        AboutView()
                    }
                } footer: {
                    Text("Craftify for Minecraft is an independent app and is not approved by or associated with Mojang or Microsoft.")
                }

                Section("Data Sync") {
                    Button(action: syncRecipes) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(dataManager.isLoading ? "Syncing Recipes…" : "Sync Recipes")
                                Text(syncDetail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            if dataManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .disabled(dataManager.isLoading || !dataManager.isConnected || remainingCooldownTime > 0)
                    .accessibilityHint(syncHint)

                    LabeledContent {
                        Text(dataManager.isConnected ? "Online" : "Offline")
                            .foregroundStyle(dataManager.isConnected ? .green : .red)
                    } label: {
                        Label("Connection", systemImage: dataManager.isConnected ? "wifi" : "wifi.slash")
                    }

                    LabeledContent("Recipes", value: dataManager.recipes.count.formatted())
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
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { dataManager.errorMessage != nil },
            set: { if !$0 { dataManager.errorMessage = nil } }
        )
    }

    private func destination<Destination: View>(
        _ title: String,
        systemImage: String,
        hint: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
        }
        .accessibilityHint(hint)
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
                    Text("A focused companion for finding Minecraft recipes and keeping your favorites close at hand.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }

            Section("Personalize") {
                NavigationLink("App Appearance", destination: AppAppearanceView())
            }

            Section("Information") {
                NavigationLink("Release Notes", destination: ReleaseNotesView())
                NavigationLink("Support & Privacy", destination: SupportView())
            }

            Section("Acknowledgements") {
                Link(destination: URL(string: "https://minecraft.wiki/")!) {
                    Label("Minecraft Wiki", systemImage: "arrow.up.right.square")
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
        .background(Color(.systemBackground))
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
