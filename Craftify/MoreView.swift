//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    @EnvironmentObject var dataManager: DataManager
    @State private var isSyncing: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header with icon and title.
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color(hex: "00AA00"))
                    Text("More")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
                
                // Settings List
                List {
                    // Appearance Section.
                    Section(header: Text("Appearance").font(.headline)) {
                        Picker("Appearance", selection: $colorSchemePreference) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // "Need help?" Section.
                    Section(header: Text("Need help?").font(.headline)) {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            if let url = URL(string: "mailto:hello@davevancauwenberghe.be") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "00AA00"))
                                Text("Report missing recipe")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color(UIColor.systemGray5))
                    }
                    
                    // About Section.
                    Section(header: Text("About").font(.headline)) {
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "00AA00"))
                                Text("About Craftify")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(Color(UIColor.systemGray5))
                    }
                    
                    // Sync Status and Recipe Count Section.
                    Section(header: Text("Data Management").font(.headline)) {
                        VStack(alignment: .center, spacing: 10) {
                            Text("\(dataManager.recipes.count) recipes available")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            // Sync Recipes Button.
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                isSyncing = true
                                dataManager.loadData {
                                    dataManager.syncFavorites()
                                    isSyncing = false
                                }
                            }) {
                                HStack {
                                    if isSyncing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .padding(.trailing, 4)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.title2)
                                            .foregroundColor(Color(hex: "00AA00"))
                                    }
                                    Text("Sync recipes")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(10)
                            }
                            
                            // Clear Cache Button.
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                dataManager.clearCache { success in
                                    if success {
                                        print("Cache cleared successfully.")
                                    } else {
                                        print("Failed to clear cache.")
                                    }
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
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("")
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Craftify for Minecraft")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Version 1.0 - Build 25")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                .multilineTextAlignment(.center)
                .padding()
            
            // New Release Notes button.
            NavigationLink(destination: ReleaseNotesView()) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "00AA00"))
                    Text("Release Notes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("About Craftify")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReleaseNotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Release Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Version 1.0 - Build 25")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Added: Image Assets
                    """)
                Text("Version 1.0 - Build 24")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Added: RecipeDetailView now shows more info regarding which utility block needs to be used
                    - CloudKit Container expanded with new strings for optional remarks
                    - Added: Image assets
                    - Asynchronous loading
                    """)
                Text("Version 1.0 - Build 22-23")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - MacOS Native Support test
                    - Added: Search on Categories
                    - Added: Basic LaunchScreen
                    """)
                Text("Version 1.0 - Build 21")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Added: Collapsible Craftify Picks
                    - Added: Image assets
                    - Removed: Share button in the RecipeDetailView
                    """)
                Text("Version 1.0 - Build 20")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Added: Updated Favorites when no favorites are added yet
                    - Update Image assets naming
                    """)
                Text("Version 1.0 - Build 14-19")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Added: Data management in More
                    - Added: Image Assets
                    - UI fixes
                    """)
                Text("Version 1.0 - Build 13")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Added: Pull to refresh
                    - Added: Local cache
                    - Added: Sync info in More
                    """)
                Text("Version 1.0 - Build 12")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - CloudKit update
                    """)
                Text("Version 1.0 - Build 11")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - CloudKit support added
                    """)
                Text("Version 1.0 - Build 1-10")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("""
                    - Initial release of Craftify for Minecraft.
                    - Recipe management and favorite syncing via CloudKit.
                    - Improved UI for crafting grid and recipe details.
                    - Enhanced haptic feedback and smooth transitions.
                    """)
                    .font(.body)
                Spacer()
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Release Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
