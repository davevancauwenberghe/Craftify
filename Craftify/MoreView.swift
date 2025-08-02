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
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var cooldownMessage: String? = nil
    @State private var remainingCooldownTime: Int = 0
    @State private var cooldownTimer: Timer? = nil
    @State private var attemptedSyncWhileOffline: Bool = false
    
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
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .accessibilityLabel("Disclaimer")
                        .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")
                }
                
                Section(header: Text("Data Sync & Status")) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 1. Sync Recipes Button + Cooldown Message
                        VStack(spacing: 8) {
                            Button(action: {
                                fetchRecipes(isUserInitiated: true)
                            }) {
                                HStack {
                                    if dataManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Color.userAccentColor)
                                            .padding(.trailing, 8)
                                            .accessibilityLabel("Syncing")
                                            .accessibilityHint("Recipes are currently syncing")
                                            .opacity(dataManager.isLoading ? 1 : 0)
                                            .animation(.easeInOut(duration: 0.3), value: dataManager.isLoading)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.title2)
                                            .foregroundColor(dataManager.isConnected ? Color.userAccentColor : Color.gray)
                                    }
                                    Text("Sync Recipes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(dataManager.isConnected ? .primary : .gray)
                                    Spacer()
                                }
                                .id(accentColorPreference)
                                .padding(horizontalSizeClass == .regular ? 16 : 12)
                                .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                                .frame(maxWidth: .infinity, minHeight: 44)
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
                                .font(.body)
                                .foregroundColor(dataManager.isConnected ? .green : .red)
                            Text(dataManager.isConnected ? "Connected to the Internet" : "No Internet Connection")
                                .font(.caption)
                                .foregroundColor(dataManager.isConnected ? .green : .red)
                            Spacer()
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? 4 : 2)
                        .accessibilityElement()
                        .accessibilityLabel(dataManager.isConnected ? "Connected to the internet" : "No internet connection")
                        .accessibilityHint(dataManager.isConnected ? "Your device is connected to the internet" : "Please connect to the internet to sync recipes")
                        // 3 & 4. Last Synced + Recipes Available
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                Text(dataManager.lastUpdated != nil ? formatSyncDate(dataManager.lastUpdated) : dataManager.syncStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .accessibilityLabel(dataManager.syncStatus)
                            HStack {
                                Image(systemName: "list.bullet")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                Text("\(dataManager.recipes.count) recipes available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .accessibilityLabel("\(dataManager.recipes.count) recipes available")
                            .accessibilityHint("Number of recipes currently available in the app")
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? 4 : 2)
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
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(Color.userAccentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
    }
}

struct AboutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    let accentColorPreference: String
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) – Build \(build)"
    }
    
    var body: some View {
        let headerText: some View = Text("Craftify for Minecraft")
            .font(horizontalSizeClass == .regular ? .title : .largeTitle)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
        
        let versionText: some View = Text(appVersion)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .minimumScaleFactor(0.6)
        
        let descriptionText: some View = Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
            .font(horizontalSizeClass == .regular ? .body : .subheadline)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
        
        let thankYouText: some View = {
            var attributed = AttributedString("A huge thank you to the Minecraft Wiki for their thorough and devoted work in creating the recipe database and thumbnails that power Craftify.")
            if let range = attributed.range(of: "Minecraft Wiki") {
                attributed[range].link = URL(string: "https://minecraft.fandom.com/wiki/Minecraft_Wiki")
                attributed[range].underlineStyle = .init(rawValue: 0)
            }
            return Text(attributed)
                .font(horizontalSizeClass == .regular ? .callout : .footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                .accessibilityLabel("Thank you to Minecraft Wiki. Tap the link to open the Minecraft Wiki in Safari.")
                .accessibilityHint("Acknowledges the Minecraft Wiki for providing recipe data and thumbnails. Tapping the link opens their site.")
        }()
        
        VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
            VStack(spacing: 8) {
                Image("AppIconPreview")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 2, x: 0, y: 1)
                    .accessibilityLabel("Craftify app icon")
                    .accessibilityAddTraits(.isImage)
                
                headerText
                versionText
                descriptionText
                    .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
            }
            .padding(.top, horizontalSizeClass == .regular ? 16 : 12)
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
                        // Haptics removed to avoid UIKit dependency
                    })
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("App Appearance")
                    .accessibilityHint("Customize the app's icon and appearance settings")
                    
                    NavigationLink(destination: ReleaseNotesView()) {
                        buttonStyle(title: "Release Notes", systemImage: "doc.text.fill")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        // Haptics removed to avoid UIKit dependency
                    })
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top: horizontalSizeClass == .regular ? 12 : 8,
                        leading: horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing: horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("Release Notes")
                    .accessibilityHint("View the release notes for Craftify")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
            
            NavigationLink(destination: SupportView()) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.title2)
                    Text("Support & Privacy")
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .bold()
                        .minimumScaleFactor(0.6)
                }
                .id(accentColorPreference)
                .frame(maxWidth: .infinity)
                .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 24)
                .background(Color.userAccentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 600 : 400)
            .padding(.bottom, 8)
            .accessibilityLabel("Support and Privacy")
            .accessibilityHint("Navigate to support and privacy options")
            
            thankYouText
            
            Text("Craftify for Minecraft is not an official Minecraft product; it is not approved or associated with Mojang or Microsoft.")
                .font(horizontalSizeClass == .regular ? .callout : .footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                .accessibilityLabel("Disclaimer")
                .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")
            
            Spacer()
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
    
    private func buttonStyle(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(Color.userAccentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
            Spacer()
        }
        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
    }
}
