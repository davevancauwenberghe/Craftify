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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText: String = ""
    @State private var editionFilter: EditionFilter = .all
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var spacingLarge: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var spacingSmall: CGFloat = 4

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
                        VStack(alignment: .leading, spacing: spacingSmall) {
                            Text("➜ \(cmd.name)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text(cmd.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: spacingLarge) {
                                HStack(spacing: spacingSmall) {
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
                                    cmd.worksInBedrock
                                        ? Color.userAccentColor
                                        : .red
                                )
                                .accessibilityLabel("Bedrock Edition \(cmd.worksInBedrock ? "supported" : "not supported")\(cmd.worksInBedrock && cmd.opLevelBedrock != nil ? ", requires OP level \(cmd.opLevelBedrock!)" : "")")
                                .accessibilityHint(cmd.worksInBedrock ? "Double tap OP level to see explanation" : "")

                                HStack(spacing: spacingSmall) {
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
                                    cmd.worksInJava
                                        ? Color.userAccentColor
                                        : .red
                                )
                                .accessibilityLabel("Java Edition \(cmd.worksInJava ? "supported" : "not supported")\(cmd.worksInJava && cmd.opLevelJava != nil ? ", requires OP level \(cmd.opLevelJava!)" : "")")
                                .accessibilityHint(cmd.worksInJava ? "Double tap OP level to see explanation" : "")
                            }
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical)
                        .listRowInsets(EdgeInsets(
                            top: horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical,
                            leading: horizontalSizeClass == .regular ? paddingHorizontal * 1.33 : paddingHorizontal,
                            bottom: horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical,
                            trailing: horizontalSizeClass == .regular ? paddingHorizontal * 1.33 : paddingHorizontal
                        ))
                        .contextMenu {
                            Button("Copy Command") {
                                UIPasteboard.general.string = cmd.name
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Command: \(cmd.name), \(cmd.description)")
                        .accessibilityHint("Double tap to copy the command")
                    }

                    Section(header: Text("OP Levels").id("opExplanation")) {
                        VStack(alignment: .leading, spacing: spacingSmall) {
                            Text("Higher OP levels include all permissions of the lower ones.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Bedrock Edition")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: spacingSmall) {
                                Text("• 1: Operator – Basic commands & command blocks")
                                Text("• 2: Admin – Server commands")
                                Text("• 3: Host – World & automation management")
                                Text("• 4: Owner – Full server control")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            Text("Java Edition")
                                .font(.headline)
                                .padding(.top, spacingSmall)
                            VStack(alignment: .leading, spacing: spacingSmall) {
                                Text("• 0: All – Basic commands")
                                Text("• 1: Moderator – Bypass spawn protection")
                                Text("• 2: GameMaster – Command blocks & extra commands")
                                Text("• 3: Admin – Multiplayer management")
                                Text("• 4: Owner – Full server control")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical)
                        .listRowInsets(EdgeInsets(
                            top: horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical,
                            leading: horizontalSizeClass == .regular ? paddingHorizontal * 1.33 : paddingHorizontal,
                            bottom: horizontalSizeClass == .regular ? paddingVertical * 1.5 : paddingVertical,
                            trailing: horizontalSizeClass == .regular ? paddingHorizontal * 1.33 : paddingHorizontal
                        ))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("OP Levels explanation: Higher OP levels include all permissions of the lower ones. Bedrock Edition: 1 Operator, basic commands and command blocks; 2 Admin, server commands; 3 Host, world and automation management; 4 Owner, full server control. Java Edition: 0 All, basic commands; 1 Moderator, bypass spawn protection; 2 GameMaster, command blocks and extra commands; 3 Admin, multiplayer management; 4 Owner, full server control.")
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    dataManager.fetchConsoleCommands()
                }
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
                                Button(action: {
                                    editionFilter = filter
                                }) {
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
                        .accessibilityLabel("Filter commands by edition")
                        .accessibilityHint("Choose All Editions, Bedrock Edition, or Java Edition")
                    }
                }
                .navigationTitle("Console Commands")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
                .preferredColorScheme(
                    colorSchemePreference == "system"
                        ? nil
                        : (colorSchemePreference == "light" ? .light : .dark)
                )
                .accentColor(Color.userAccentColor)
                .onAppear {
                    dataManager.fetchConsoleCommands()
                }
                .dynamicTypeSize(.xSmall ... .accessibility5)
            }
        }
    }
}
