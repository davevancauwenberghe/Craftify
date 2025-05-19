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
    @State private var cooldownMessage: String? = nil // New state for cooldown message

    private func formatSyncDate(_ date: Date?) -> String {
        guard let date = date else { return "Not synced" }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Synced: \(formatter.string(from: date))"
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
                
                Section(header: Text("Data Management")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(dataManager.recipes.count) recipes available")
                            Text(dataManager.lastUpdated != nil ? formatSyncDate(dataManager.lastUpdated) : dataManager.syncStatus)
                        }
                        .font(horizontalSizeClass == .regular ? .callout : .footnote)
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(dataManager.recipes.count) recipes available, \(dataManager.syncStatus)")
                        .accessibilityHint("Information about the number of recipes and sync status")
                        
                        Button(action: {
                            print("Sync Recipes tapped")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.fetchRecipes(isManual: true) {
                                print("Sync Recipes completed")
                                // Check if the fetch was skipped due to the 30-second cooldown
                                if dataManager.isRecipeFetchOnCooldown() {
                                    cooldownMessage = "Please wait 30 seconds before syncing again."
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        cooldownMessage = nil
                                    }
                                }
                            }
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
                                        .foregroundColor(Color.userAccentColor)
                                }
                                Text("Sync Recipes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .id(accentColorPreference)
                            .padding(horizontalSizeClass == .regular ? 16 : 12)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .disabled(dataManager.isLoading)
                        .accessibilityLabel("Sync Recipes")
                        .accessibilityHint("Syncs Minecraft recipes from CloudKit")

                        // Cooldown Message
                        if let message = cooldownMessage {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel(message)
                        }
                        
                        Button(action: {
                            print("Clear Cache tapped")
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dataManager.clearCache { success in
                                if !success {
                                    dataManager.errorMessage = "Failed to clear cache. Please try again."
                                }
                                print("Clear Cache completed, success: \(success)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Clear Cache")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .id(accentColorPreference)
                            .padding(horizontalSizeClass == .regular ? 16 : 12)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Clear Cache")
                        .accessibilityHint("Clears the cached Minecraft recipes")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
            .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
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
                // Sync favorites, recent searches, and fetch recipes
                dataManager.syncFavorites()
                dataManager.syncRecentSearches()
                dataManager.fetchRecipes(isManual: false)
            }
            .onChange(of: dataManager.isLoading) { _, newValue in
                if !newValue && dataManager.isManualSyncing {
                    dataManager.accessibilityAnnouncement = "Sync completed"
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
    let accentColorPreference: String

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) – Build \(build)"
    }

    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
            VStack(spacing: 8) {
                Image(uiImage: UIImage(named: "AppIconPreview") ?? UIImage(systemName: "app.fill")!)
                    .resizable()
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

                Text("Craftify for Minecraft")
                    .font(horizontalSizeClass == .regular ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
            }
            .padding(.top, horizontalSizeClass == .regular ? 16 : 12)
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
                        top:    horizontalSizeClass == .regular ? 12 : 8,
                        leading:horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing:horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("App Appearance")
                    .accessibilityHint("Customize the app's icon and appearance settings")

                    NavigationLink(destination: ReleaseNotesView()) {
                        buttonStyle(title: "Release notes", systemImage: "doc.text.fill")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(
                        top:    horizontalSizeClass == .regular ? 12 : 8,
                        leading:horizontalSizeClass == .regular ? 16 : 12,
                        bottom: horizontalSizeClass == .regular ? 12 : 8,
                        trailing:horizontalSizeClass == .regular ? 16 : 12
                    ))
                    .accessibilityLabel("Release notes")
                    .accessibilityHint("View the release notes for Craftify")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .scrollDisabled(true)
            .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)

            NavigationLink(destination: SupportView()) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Support & Privacy")
                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                        .bold()
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

            Text("Craftify for Minecraft is not an official Minecraft product; it is not approved or associated with Mojang or Microsoft.")
                .font(horizontalSizeClass == .regular ? .callout : .footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                .accessibilityLabel("Disclaimer")
                .accessibilityHint("Craftify is not an official Minecraft product and is not associated with Mojang or Microsoft")

            Spacer()
        }
        .padding(horizontalSizeClass == .regular ? 12 : 8)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .safeAreaInset(edge: .top)    { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
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
