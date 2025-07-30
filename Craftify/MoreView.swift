//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct MoreView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var cooldownMessage: String? = nil
    @State private var remainingCooldownTime: Int = 0
    @State private var cooldownTimer: Timer? = nil
    @State private var attemptedSyncWhileOffline: Bool = false
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 44

    private func formatSyncDate(_ date: Date?) -> String {
        guard let date = date else { return "Not synced" }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Last synced: \(formatter.string(from: date))"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Need Help?")) {
                    NavigationLink(destination: ReportRecipeView()) {
                        buttonStyle(title: "Report Issue", systemImage: "envelope.fill")
                    }
                    .accessibilityLabel("Report Issue")
                    .accessibilityHint("Navigate to report a missing recipe or an error in an existing recipe")
                    
                    NavigationLink(destination: CommandsView()) {
                        buttonStyle(title: "Console Commands", systemImage: "terminal.fill")
                    }
                    .accessibilityLabel("Console Commands")
                    .accessibilityHint("Navigate to view in-game console commands")
                }
                
                Section(header: Text("About")) {
                    NavigationLink(destination: AboutView(accentColorPreference: accentColorPreference)) {
                        buttonStyle(title: "About Craftify", systemImage: "info.circle.fill")
                    }
                    .accessibilityLabel("About Craftify")
                    .accessibilityHint("View information about the Craftify app")
                    
                    Text("Craftify for Minecraft is not an official Minecraft product, it is not approved or associated with Mojang or Microsoft.")
                        .font(horizontalSizeClass == .regular ? .callout : .footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical)
                        .accessibilityLabel("Disclaimer")
                        .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")
                }
                
                Section(header: Text("Data Sync & Status")) {
                    VStack(alignment: .leading, spacing: spacing) {
                        // 1. Sync Recipes Button + Cooldown Message
                        VStack(spacing: spacing) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                fetchRecipes(isUserInitiated: true)
                            }) {
                                HStack {
                                    if dataManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Color.userAccentColor)
                                            .padding(.trailing, spacing)
                                            .accessibilityLabel("Syncing")
                                            .accessibilityHint("Recipes are currently syncing")
                                            .opacity(dataManager.isLoading ? 1 : 0)
                                            .animation(.easeInOut(duration: 0.3), value: dataManager.isLoading)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: spacing * 1.5))
                                            .foregroundColor(dataManager.isConnected ? Color.userAccentColor : Color.gray)
                                    }
                                    Text("Sync Recipes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(dataManager.isConnected ? .primary : .gray)
                                    Spacer()
                                }
                                .id(accentColorPreference)
                                .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.33 : paddingHorizontal)
                                .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical : paddingVertical * 0.75)
                                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                                .background(Color.gray.opacity(dataManager.isConnected ? 0.1 : 0.05))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .disabled(dataManager.isLoading || !dataManager.isConnected)
                            .accessibilityLabel("Sync Recipes")
                            .accessibilityHint(dataManager.isConnected ? "Syncs Minecraft recipes from CloudKit" : "Sync is disabled due to no internet connection")

                            if let message = cooldownMessage, dataManager.isConnected {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .accessibilityLabel(message)
                            }
                        }

                        // 2. Network Status
                        HStack {
                            Image(systemName: dataManager.isConnected ? "wifi" : "wifi.slash")
                                .font(.system(size: spacing * 1.5))
                                .foregroundColor(dataManager.isConnected ? .green : .red)
                            Text(dataManager.isConnected ? "Connected to the Internet" : "No Internet Connection")
                                .font(.caption)
                                .foregroundColor(dataManager.isConnected ? .green : .red)
                            Spacer()
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 0.5 : paddingVertical * 0.25)
                        .accessibilityElement()
                        .accessibilityLabel(dataManager.isConnected ? "Connected to the internet" : "No internet connection")
                        .accessibilityHint(dataManager.isConnected ? "Your device is connected to the internet" : "Please connect to the internet to sync recipes")

                        // 3 & 4. Last Synced + Recipes Available
                        VStack(spacing: spacing) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: spacing * 1.5))
                                    .foregroundColor(.gray)
                                    .frame(width: spacing * 1.5)
                                Text(dataManager.lastUpdated != nil ? formatSyncDate(dataManager.lastUpdated) : dataManager.syncStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, spacing * 0.25)
                            .accessibilityLabel(dataManager.syncStatus)

                            HStack {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: spacing * 1.5))
                                    .foregroundColor(.gray)
                                    .frame(width: spacing * 1.5)
                                Text("\(dataManager.recipes.count) recipes available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, spacing * 0.25)
                            .accessibilityLabel("\(dataManager.recipes.count) recipes available")
                            .accessibilityHint("Number of recipes currently available in the app")
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 0.5 : paddingVertical * 0.25)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Last synced and recipes available: \(dataManager.syncStatus), \(dataManager.recipes.count) recipes available")
                        .accessibilityHint("Manage recipe syncing, view network status, last sync time, and number of recipes available")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Data Sync and Status: Sync Recipes button, \(dataManager.isConnected ? "Connected to the internet" : "No internet connection"), \(dataManager.syncStatus), \(dataManager.recipes.count) available")
                    .accessibilityHint("Manage recipe syncing, view network status, last sync time, and number of recipes available")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
            .alert(isPresented: Binding(
                get: { dataManager.errorMessage != nil },
                set: { if !$0 { dataManager.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(dataManager.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                dataManager.syncFavorites()
                dataManager.syncRecentSearches()
            }
            .onChange(of: dataManager.isLoading) { _, newValue in
                if !newValue && dataManager.isManualSyncing {
                    dataManager.accessibilityAnnouncement = "Sync completed"
                }
            }
            .onChange(of: dataManager.isConnected) { _, newValue in
                if newValue && attemptedSyncWhileOffline {
                    fetchRecipes(isUserInitiated: false)
                    attemptedSyncWhileOffline = false
                    dataManager.accessibilityAnnouncement = "Reconnected to the internet. Retrying sync."
                }
            }
            .onDisappear {
                cooldownTimer?.invalidate()
                cooldownTimer = nil
                cooldownMessage = nil
                remainingCooldownTime = 0
            }
            .dynamicTypeSize(.xSmall ... .accessibility5)
        }
    }
    
    private func fetchRecipes(isUserInitiated: Bool) {
        dataManager.fetchRecipes(isManual: true) {
            DispatchQueue.main.async {
                if !dataManager.isConnected {
                    attemptedSyncWhileOffline = true
                }
                if self.dataManager.isRecipeFetchOnCooldown() && isUserInitiated {
                    let cooldownDuration = 30
                    let lastFetchTime = self.dataManager.lastRecipeFetch ?? Date.distantPast
                    let elapsed = Int(Date().timeIntervalSince(lastFetchTime))
                    self.remainingCooldownTime = max(0, cooldownDuration - elapsed)
                    
                    if self.remainingCooldownTime > 0 {
                        self.cooldownMessage = "Please wait \(self.remainingCooldownTime) second\(self.remainingCooldownTime == 1 ? "" : "s") before syncing again."
                        self.startCooldownTimer()
                    }
                }
            }
        }
    }

    private func startCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.remainingCooldownTime > 0 {
                    self.remainingCooldownTime -= 1
                    self.cooldownMessage = "Please wait \(self.remainingCooldownTime) second\(self.remainingCooldownTime == 1 ? "" : "s") before syncing again."
                } else {
                    self.cooldownMessage = nil
                    self.remainingCooldownTime = 0
                    timer.invalidate()
                    self.cooldownTimer = nil
                }
            }
        }
    }
    
    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack(spacing: spacing) {
            Image(systemName: systemImage)
                .font(.system(size: spacing * 1.5))
                .foregroundColor(Color.userAccentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical)
    }
}

struct AboutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var buttonWidth: CGFloat = 300
    @ScaledMetric(relativeTo: .body) private var listRowPadding: CGFloat = 8

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) – Build \(build)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: horizontalSizeClass == .regular ? spacing * 1.25 : spacing) {
                    VStack(spacing: spacing * 0.5) {
                        Image(uiImage: UIImage(named: "AppIconPreview") ?? UIImage(systemName: "square.grid.3x3.fill")!)
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(iconSize, 120), height: min(iconSize, 120))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(radius: 2, x: 0, y: 1)
                            .accessibilityLabel("Craftify app icon")
                            .accessibilityAddTraits(.isImage)

                        Text("Craftify for Minecraft")
                            .font(horizontalSizeClass == .regular ? .title : .largeTitle)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)

                        Text(appVersion)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .minimumScaleFactor(0.6)

                        Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                            .font(horizontalSizeClass == .regular ? .body : .subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, horizontalSizeClass == .regular ? min(paddingHorizontal * 1.5, 24) : paddingHorizontal)
                    }
                    .padding(.top, horizontalSizeClass == .regular ? paddingVertical * 1.33 : paddingVertical)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Craftify for Minecraft, \(appVersion). Craftify helps you manage your recipes and favorites.")
                    .accessibilityHint("About the Craftify app and its purpose")

                    List {
                        Section {
                            NavigationLink(destination: AppAppearanceView()) {
                                buttonStyle(title: "App Appearance", systemImage: "app.badge.fill")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            })
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(
                                top: listRowPadding,
                                leading: horizontalSizeClass == .regular ? min(listRowPadding * 1.33, 16) : listRowPadding,
                                bottom: listRowPadding,
                                trailing: horizontalSizeClass == .regular ? min(listRowPadding * 1.33, 16) : listRowPadding
                            ))
                            .accessibilityLabel("App Appearance")
                            .accessibilityHint("Customize the app's icon and appearance settings")

                            NavigationLink(destination: ReleaseNotesView()) {
                                buttonStyle(title: "Release Notes", systemImage: "doc.text.fill")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            })
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(
                                top: listRowPadding,
                                leading: horizontalSizeClass == .regular ? min(listRowPadding * 1.33, 16) : listRowPadding,
                                bottom: listRowPadding,
                                trailing: horizontalSizeClass == .regular ? min(listRowPadding * 1.33, 16) : listRowPadding
                            ))
                            .accessibilityLabel("Release Notes")
                            .accessibilityHint("View the release notes for Craftify")
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .padding(.horizontal, horizontalSizeClass == .regular ? min(paddingHorizontal * 1.5, 24) : paddingHorizontal)

                    NavigationLink(destination: SupportView()) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: min(listRowPadding * 1.5, 18)))
                            Text("Support & Privacy")
                                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                .bold()
                        }
                        .id(accentColorPreference)
                        .frame(maxWidth: min(buttonWidth, 400))
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.33 : paddingVertical)
                        .padding(.horizontal, horizontalSizeClass == .regular ? min(paddingHorizontal * 2, 32) : min(padingHorizontal * 1.5, 24))
                        .background(Color.userAccentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .accessibilityLabel("Support and Privacy")
                    .accessibilityHint("Navigate to support and privacy options")

                    Text("Craftify for Minecraft is not an official Minecraft product; it is not approved or associated with Mojang or Microsoft.")
                        .font(horizontalSizeClass == .regular ? .callout : .footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, horizontalSizeClass == .regular ? min(paddingHorizontal * 1.5, 24) : paddingHorizontal)
                        .padding(.bottom, paddingVertical)
                        .accessibilityLabel("Disclaimer")
                        .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? min(paddingHorizontal * 1.5, 24) : paddingHorizontal)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("About Craftify")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
            .dynamicTypeSize(.xSmall ... .accessibility5)
        }
    }

    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack(spacing: spacing) {
            Image(systemName: systemImage)
                .font(.system(size: min(listRowPadding * 1.5, 18)))
                .foregroundColor(Color.userAccentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, listRowPadding)
    }
}
