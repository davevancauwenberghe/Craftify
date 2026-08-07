//
//  CommandsView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 27/06/2025.
//

import SwiftUI
import UIKit

struct CommandsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @State private var editionFilter: EditionFilter = .all
    @State private var copiedCommandID: String?

    private enum EditionFilter: String, CaseIterable, Identifiable {
        case all = "All Editions"
        case bedrock = "Bedrock Edition"
        case java = "Java Edition"

        var id: Self { self }
        var symbol: String {
            switch self {
            case .all: "square.stack.3d.up.fill"
            case .bedrock: "cube.fill"
            case .java: "cup.and.heat.waves.fill"
            }
        }
    }

    private var filteredCommands: [ConsoleCommand] {
        dataManager.consoleCommands
            .filter { command in
                switch editionFilter {
                case .all: true
                case .bedrock: command.worksInBedrock
                case .java: command.worksInJava
                }
            }
            .filter { command in
                searchText.isEmpty
                    || command.name.localizedCaseInsensitiveContains(searchText)
                    || command.description.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var columns: [GridItem] {
        CraftifyLayout.adaptiveColumns(
            minimum: dynamicTypeSize.isAccessibilitySize ? 300 : 310,
            maximum: 480,
            spacing: 14,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    CraftifyHero(
                        eyebrow: "Minecraft Reference",
                        title: "Console Commands",
                        detail: "Find commands for Bedrock and Java Edition, check operator requirements, and copy the exact command in one tap.",
                        symbol: "terminal.fill"
                    )

                    HStack {
                        CraftifyStatusPill(
                            title: editionFilter.rawValue,
                            symbol: editionFilter.symbol
                        )
                        Spacer()
                        Text("\(filteredCommands.count) command\(filteredCommands.count == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if filteredCommands.isEmpty {
                        CraftifyEmptyState(
                            symbol: "terminal",
                            title: "No Commands Found",
                            detail: "Try another search term or choose a different Minecraft edition."
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                            ForEach(filteredCommands) { command in
                                CommandCard(
                                    command: command,
                                    isCopied: copiedCommandID == command.id,
                                    onCopy: { copy(command) },
                                    onShowOPLevels: {
                                        withAnimation(.easeInOut) {
                                            proxy.scrollTo("opExplanation", anchor: .top)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    OPLevelsCard()
                        .id("opExplanation")
                }
                .craftifyContentWidth()
                .padding(.horizontal, CraftifyLayout.pagePadding(for: horizontalSizeClass))
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .refreshable { dataManager.fetchConsoleCommands() }
            .navigationTitle("Console Commands")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search commands"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(EditionFilter.allCases) { filter in
                            Button {
                                editionFilter = filter
                                HapticFeedback.selection()
                            } label: {
                                Label(filter.rawValue, systemImage: editionFilter == filter ? "checkmark" : filter.symbol)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter commands by edition")
                    .accessibilityValue(editionFilter.rawValue)
                }
            }
            .craftifyPage()
            .onAppear { dataManager.fetchConsoleCommands() }
        }
    }

    private func copy(_ command: ConsoleCommand) {
        UIPasteboard.general.string = command.name
        copiedCommandID = command.id
        HapticFeedback.notification(.success)
        UIAccessibility.post(notification: .announcement, argument: "Copied \(command.name)")

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if copiedCommandID == command.id { copiedCommandID = nil }
        }
    }
}

private struct CommandCard: View {
    let command: ConsoleCommand
    let isCopied: Bool
    let onCopy: () -> Void
    let onShowOPLevels: () -> Void

    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                Text(command.name)
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(isCopied ? "Command copied" : "Copy command")
            }

            Text(command.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 9) { editionBadges }
                VStack(alignment: .leading, spacing: 9) { editionBadges }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .craftifyCard(cornerRadius: 20)
        .contextMenu {
            Button("Copy Command", systemImage: "doc.on.doc", action: onCopy)
        }
    }

    @ViewBuilder
    private var editionBadges: some View {
        CommandEditionBadge(
            title: "Bedrock",
            isSupported: command.worksInBedrock,
            opLevel: command.opLevelBedrock,
            onShowOPLevels: onShowOPLevels
        )
        CommandEditionBadge(
            title: "Java",
            isSupported: command.worksInJava,
            opLevel: command.opLevelJava,
            onShowOPLevels: onShowOPLevels
        )
    }
}

private struct CommandEditionBadge: View {
    let title: String
    let isSupported: Bool
    let opLevel: Int64?
    let onShowOPLevels: () -> Void
    @Environment(\.craftifyAccentColor) private var accent

    private var opColor: Color {
        switch opLevel {
        case 1: .red
        case 2: .orange
        case 3: .yellow
        case 4: .green
        default: .gray
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(title)
                .font(.caption.weight(.semibold))

            if isSupported, let opLevel {
                Button("OP \(opLevel)", action: onShowOPLevels)
                    .font(.caption2.bold())
                    .foregroundStyle(opColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(opColor.opacity(0.12), in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityHint("Jumps to the operator level explanation")
            }
        }
        .foregroundStyle(isSupported ? accent : Color.red)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            (isSupported ? accent : Color.red).opacity(0.08),
            in: Capsule()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) Edition \(isSupported ? "supported" : "not supported")")
    }
}

private struct OPLevelsCard: View {
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CraftifySectionHeader(
                title: "Operator Levels",
                detail: "Higher levels include every permission from the lower levels.",
                symbol: "person.badge.key.fill"
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    edition(title: "Bedrock Edition", symbol: "cube.fill", levels: bedrockLevels)
                    edition(title: "Java Edition", symbol: "cup.and.heat.waves.fill", levels: javaLevels)
                }
                VStack(alignment: .leading, spacing: 18) {
                    edition(title: "Bedrock Edition", symbol: "cube.fill", levels: bedrockLevels)
                    edition(title: "Java Edition", symbol: "cup.and.heat.waves.fill", levels: javaLevels)
                }
            }
        }
        .padding(20)
        .craftifyCard(cornerRadius: 24)
    }

    private var bedrockLevels: [(String, String)] {
        [
            ("1 · Operator", "Basic commands and command blocks"),
            ("2 · Admin", "Server commands"),
            ("3 · Host", "World and automation management"),
            ("4 · Owner", "Full server control")
        ]
    }

    private var javaLevels: [(String, String)] {
        [
            ("0 · All", "Basic commands"),
            ("1 · Moderator", "Bypass spawn protection"),
            ("2 · GameMaster", "Command blocks and extra commands"),
            ("3 · Admin", "Multiplayer management"),
            ("4 · Owner", "Full server control")
        ]
    }

    private func edition(title: String, symbol: String, levels: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(accent)
            ForEach(levels, id: \.0) { level in
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.0).font(.subheadline.bold())
                    Text(level.1).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(15)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
