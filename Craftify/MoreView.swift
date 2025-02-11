//
//  MoreView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 09/02/2025.
//

import SwiftUI

struct MoreView: View {
    // Persist the appearance selection using AppStorage.
    // Allowed values: "system", "light", or "dark"
    @AppStorage("colorSchemePreference") var colorSchemePreference: String = "system"
    
    @EnvironmentObject var dataManager: DataManager

    // A date formatter to display the last sync time.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header with an icon and custom title.
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
                .padding(.bottom, 8) // Slightly reduced bottom padding for header
                
                // Sync Status View
                Group {
                    if let lastUpdated = dataManager.lastUpdated {
                        Text("Recipes synced: \(lastUpdated, formatter: Self.dateFormatter)")
                    } else {
                        Text("Recipes not yet synced")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Settings List
                List {
                    // Appearance Section
                    Section(header: Text("Appearance")
                                .font(.headline)
                                .foregroundColor(.primary)) {
                        Picker("Appearance", selection: $colorSchemePreference) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // "Need help?" Section
                    Section(header: Text("Need help?")
                                .font(.headline)
                                .foregroundColor(.primary)) {
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
                            .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color(UIColor.systemGray5))
                    }
                    
                    // About Section
                    Section(header: Text("About")
                                .font(.headline)
                                .foregroundColor(.primary)) {
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
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(Color(UIColor.systemGray5))
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("") // Custom header serves as title.
        }
        .preferredColorScheme(
            colorSchemePreference == "system" ? nil :
            (colorSchemePreference == "light" ? .light : .dark)
        )
    }
}

// Stub view for AboutView – expand as needed.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Craftify for Minecraft")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Version 1.0 - Build 13")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Craftify helps you manage your recipes and favorites. If you encounter any missing recipes or issues, please let us know!")
                .multilineTextAlignment(.center)
                .padding()
            
            // New Release Notes button
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

// Stub view for ReleaseNotesView – expand as needed.
struct ReleaseNotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Release Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
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
            }
            .padding()
        }
        .navigationTitle("Release Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
