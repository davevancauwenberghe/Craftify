//
//  CommandsView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 27/06/2025.
//

import SwiftUI

struct CommandsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var searchText: String = ""
    @State private var editionFilter: EditionFilter = .all

    private enum EditionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case bedrock = "Bedrock"
        case java = "Java"
        var id: String { rawValue }
    }

    private var filteredCommands: [ConsoleCommand] {
        dataManager.consoleCommands
            .filter { cmd in
                switch editionFilter {
                case .all:     return true
                case .bedrock: return cmd.worksInBedrock
                case .java:    return cmd.worksInJava
                }
            }
            .filter { cmd in
                searchText.isEmpty ||
                cmd.name.lowercased().contains(searchText.lowercased()) ||
                cmd.description.lowercased().contains(searchText.lowercased())
            }
    }
    
    /// Maps an OP level (1–4) to a corresponding Color
    private func color(forOP level: Int64) -> Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                NavigationStack {
                    List {
                        // Commands
                        Section {
                            ForEach(filteredCommands) { command in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("➜ \(command.name)")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    Text(command.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 16) {
                                        // Bedrock badge + OP tag
                                        HStack(spacing: 4) {
                                            Image(systemName: command.worksInBedrock
                                                  ? "checkmark.circle.fill"
                                                  : "xmark.circle.fill")
                                            Text("Bedrock")
                                                .font(.caption)
                                            if let lvl = command.opLevelBedrock {
                                                Button {
                                                    withAnimation {
                                                        proxy.scrollTo("opExplanation", anchor: .top)
                                                    }
                                                } label: {
                                                    Text("OP \(lvl)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 6)
                                                        .background(
                                                            Capsule()
                                                                .fill(color(forOP: lvl).opacity(0.2))
                                                        )
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(color(forOP: lvl), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .foregroundColor(
                                            command.worksInBedrock
                                                ? Color.userAccentColor
                                                : .red
                                        )

                                        // Java badge + OP tag
                                        HStack(spacing: 4) {
                                            Image(systemName: command.worksInJava
                                                  ? "checkmark.circle.fill"
                                                  : "xmark.circle.fill")
                                            Text("Java")
                                                .font(.caption)
                                            if let lvl = command.opLevelJava {
                                                Button {
                                                    withAnimation {
                                                        proxy.scrollTo("opExplanation", anchor: .top)
                                                    }
                                                } label: {
                                                    Text("OP \(lvl)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 6)
                                                        .background(
                                                            Capsule()
                                                                .fill(color(forOP: lvl).opacity(0.2))
                                                        )
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(color(forOP: lvl), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .foregroundColor(
                                            command.worksInJava
                                                ? Color.userAccentColor
                                                : .red
                                        )
                                    }
                                }
                                .padding(.vertical, 8)
                                .listRowBackground(Color(.systemBackground))
                            }
                        }

                        // OP explanation
                        Section(header: Text("What is OP?").id("opExplanation")) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Effect levels are incremental, meaning level n+1 allows everything level n allows.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Group {
                                    Text("Java Edition")
                                        .font(.headline)
                                    Text("""
                                    • Level 1 (moderator): Bypass spawn protection.  
                                    • Level 2 (gamemaster): Use more commands & command blocks.  
                                    • Level 3 (admin): Multiplayer management commands.  
                                    • Level 4 (owner): All commands, including server management.
                                    """)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Group {
                                    Text("Bedrock Edition")
                                        .font(.headline)
                                    Text("Levels inherit all commands from previous levels; use the corresponding level tag to indicate required OP level.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                Group {
                                    Text("Definition")
                                        .font(.headline)

                                    Text("Java Edition:")
                                        .font(.subheadline)
                                    Text("Permission levels: 0 (all), 1 (moderator), 2 (gamemaster), 3 (admin), 4 (owner).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("""
                                    • Command blocks & functions: level 2  
                                    • Server console: level 4  
                                    • Singleplayer/LAN owner with cheats: level 4  
                                    • Otherwise: level 0
                                    """)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Group {
                                    Text("Bedrock Edition:")
                                        .font(.subheadline)
                                    Text("Permission levels: 0 (Any/Normal), 1 (Operator), 2 (Admin), 3 (Host/Automation), 4 (Owner).")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("""
                                    • Command blocks & scripts: level 1  
                                    • Server console: level 4  
                                    • Dedicated server OP: default level 1  
                                    • LAN OP with cheats: level 3  
                                    • Otherwise: level 0
                                    """)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text("Note: Bedrock’s UI permission roles (Visitor/Member/Operator/Custom) differ from command OP levels; only 'Operator Commands' toggles affect command permissions.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color(.systemBackground))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "Search commands…")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                ForEach(EditionFilter.allCases) { filter in
                                    Button(filter.rawValue) {
                                        editionFilter = filter
                                    }
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .imageScale(.large)
                            }
                            .accessibilityLabel("Filter commands by edition")
                            .accessibilityHint("Choose All, Bedrock, or Java")
                        }
                    }
                    .navigationTitle("Console Commands")
                    .navigationBarTitleDisplayMode(.inline)
                    .preferredColorScheme(
                        colorSchemePreference == "system" ? nil :
                            (colorSchemePreference == "light" ? .light : .dark)
                    )
                    .accentColor(Color.userAccentColor)
                    .onAppear {
                        dataManager.fetchConsoleCommands()
                    }
                }
            }
        }
    }
}
