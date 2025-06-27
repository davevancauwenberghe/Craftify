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
        case all     = "All Editions"
        case bedrock = "Bedrock Edition"
        case java    = "Java Edition"
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
                searchText.isEmpty
                    || cmd.name.localizedCaseInsensitiveContains(searchText)
                    || cmd.description.localizedCaseInsensitiveContains(searchText)
            }
    }

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
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(filteredCommands) { cmd in
                        VStack(alignment: .leading, spacing: 6) {
                            // Monospaced command label
                            Text("➜ \(cmd.name)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            // Description
                            Text(cmd.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            // Edition support + OP levels
                            HStack(spacing: 16) {
                                // Bedrock
                                HStack(spacing: 4) {
                                    Image(systemName: cmd.worksInBedrock
                                          ? "checkmark.circle.fill"
                                          : "xmark.circle.fill")
                                    Text("Bedrock")
                                        .font(.caption)
                                    if let lvl = cmd.opLevelBedrock {
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
                                            .onTapGesture {
                                                withAnimation {
                                                    proxy.scrollTo("opExplanation", anchor: .top)
                                                }
                                            }
                                    }
                                }
                                .foregroundColor(
                                    cmd.worksInBedrock ? Color.userAccentColor : .red
                                )

                                // Java
                                HStack(spacing: 4) {
                                    Image(systemName: cmd.worksInJava
                                          ? "checkmark.circle.fill"
                                          : "xmark.circle.fill")
                                    Text("Java")
                                        .font(.caption)
                                    if let lvl = cmd.opLevelJava {
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
                                            .onTapGesture {
                                                withAnimation {
                                                    proxy.scrollTo("opExplanation", anchor: .top)
                                                }
                                            }
                                    }
                                }
                                .foregroundColor(
                                    cmd.worksInJava ? Color.userAccentColor : .red
                                )
                            }
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .listRowInsets(EdgeInsets(
                            top: horizontalSizeClass == .regular ? 12 : 8,
                            leading: horizontalSizeClass == .regular ? 16 : 12,
                            bottom: horizontalSizeClass == .regular ? 12 : 8,
                            trailing: horizontalSizeClass == .regular ? 16 : 12
                        ))
                        // context menu on long press
                        .contextMenu {
                            Button("Copy Command") {
                                UIPasteboard.general.string = cmd.name
                            }
                        }
                    }

                    // OP Levels explanation
                    Section(header: Text("OP Levels").id("opExplanation")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Higher OP levels include all permissions of the lower ones.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Bedrock Edition")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 1: Operator – Basic commands & command blocks")
                                Text("• 2: Admin – Server commands")
                                Text("• 3: Host – World & automation management")
                                Text("• 4: Owner – Full server control")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            Text("Java Edition")
                                .font(.headline)
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 0: All – Basic commands")
                                Text("• 1: Moderator – Bypass spawn protection")
                                Text("• 2: GameMaster – Command blocks & extra commands")
                                Text("• 3: Admin – Multiplayer management")
                                Text("• 4: Owner – Full server control")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                        .listRowInsets(EdgeInsets(
                            top: horizontalSizeClass == .regular ? 12 : 8,
                            leading: horizontalSizeClass == .regular ? 16 : 12,
                            bottom: horizontalSizeClass == .regular ? 12 : 8,
                            trailing: horizontalSizeClass == .regular ? 16 : 12
                        ))
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.systemGroupedBackground))
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search commands…"
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(EditionFilter.allCases) { filter in
                                Button(action: { editionFilter = filter }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if filter == editionFilter {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .imageScale(.large)
                        }
                    }
                }
                .navigationTitle("Console Commands")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
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
