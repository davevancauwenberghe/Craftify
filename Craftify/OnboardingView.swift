//
//  OnboardingView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 16/05/2025.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var dataManager: DataManager

    let title: String
    let message: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let isFirstLaunch: Bool
    let dismissAfterLoading: Bool
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var step = 0
    @State private var isFinishing = false
    @State private var retryCount = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            onboardingBackground

            if isLoading || errorMessage != nil {
                loadingView
                    .transition(.opacity)
            } else {
                onboardingPages
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .tint(Color.userAccentColor(for: accentColorPreference))
        .dynamicTypeSize(.xSmall ... .accessibility5)
        .mask {
            SlidingDoorMask(progress: isFinishing && !reduceMotion ? 1 : 0)
                .ignoresSafeArea()
        }
        .animation(pageAnimation, value: isLoading)
        .animation(pageAnimation, value: errorMessage)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sensoryFeedback(.success, trigger: isFinishing)
        .onChange(of: isLoading) { _, loading in
            guard dismissAfterLoading, !loading, errorMessage == nil, !isFirstLaunch else { return }
            finishOnboarding()
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            AppBackground()

            CraftifyBlockGlow()
                .frame(width: horizontalSizeClass == .regular ? 430 : 290)
                .offset(x: horizontalSizeClass == .regular ? 270 : 165, y: -280)
        }
        .ignoresSafeArea()
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            appMark

            VStack(spacing: 10) {
                Text(title)
                    .font(horizontalSizeClass == .regular ? .largeTitle : .title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(errorMessage == nil ? message : "We couldn't prepare your recipe book.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                VStack(spacing: 18) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again", systemImage: "arrow.clockwise") {
                        retryCount += 1
                        onRetry()
                    }
                    .buttonStyle(CraftifyPrimaryButtonStyle())
                    .sensoryFeedback(.impact(weight: .medium), trigger: retryCount)
                    .accessibilityHint("Retries loading the Craftify recipe library")
                }
            } else {
                recipeBookProgressView
            }

            Spacer()
            Text("Everything you need to craft with confidence")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, pagePadding)
        .padding(.vertical, 28)
        .frame(maxWidth: 620)
    }

    @ViewBuilder
    private var recipeBookProgressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.userAccentColor(for: accentColorPreference))
                .accessibilityHidden(true)

            switch dataManager.recipeBookLoadingPhase {
            case .idle:
                Text("Building your recipe book…")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Building your recipe book")

            case .downloadingRecipes(let downloaded, let total):
                if let total {
                    let displayedTotal = max(total, downloaded)
                    loadingProgressRow(
                        title: "Recipes",
                        symbol: "book.closed.fill",
                        completed: downloaded,
                        total: displayedTotal
                    )
                } else {
                    Text("Downloading recipes… \(downloaded)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(downloaded) recipes downloaded")
                }

            case .preparingImages(let prepared, let total, let recipeTotal):
                loadingProgressRow(
                    title: "Recipes",
                    symbol: "book.closed.fill",
                    completed: recipeTotal,
                    total: recipeTotal
                )
                loadingProgressRow(
                    title: "Images",
                    symbol: "photo.stack.fill",
                    completed: prepared,
                    total: total
                )
            }
        }
        .frame(maxWidth: 360)
        .animation(.easeInOut(duration: 0.25), value: dataManager.recipeBookLoadingPhase)
    }

    private func loadingProgressRow(
        title: String,
        symbol: String,
        completed: Int,
        total: Int
    ) -> some View {
        let safeTotal = max(total, 1)
        let safeCompleted = total == 0 ? safeTotal : min(completed, safeTotal)

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Label(title, systemImage: symbol)
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(completed) / \(total)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            ProgressView(value: Double(safeCompleted), total: Double(safeTotal))
                .progressViewStyle(.linear)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(completed) of \(total) \(title.lowercased()) prepared")
    }

    private var onboardingPages: some View {
        // ForEach content can be evaluated by SwiftUI's asynchronous renderer.
        // Capture actor-isolated state before constructing either collection.
        let pageItems = pages
        let currentStep = step
        let accentColor = Color.userAccentColor(for: accentColorPreference)
        let animation = pageAnimation
        let horizontalPadding = pagePadding

        return VStack(spacing: 0) {
            TabView(selection: $step) {
                ForEach(Array(pageItems.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page, isCurrent: currentStep == index)
                        .tag(index)
                        .padding(.horizontal, horizontalPadding)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityLabel("Craftify introduction")
            .accessibilityValue(
                "Page \(currentStep + 1) of \(pageItems.count): \(pageItems[currentStep].title)"
            )

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(pageItems.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? accentColor : Color.secondary.opacity(0.22))
                            .frame(width: index == currentStep ? 28 : 8, height: 8)
                            .animation(animation, value: currentStep)
                    }
                }
                .accessibilityHidden(true)

                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button("Back") {
                            move(to: currentStep - 1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityHint("Shows the previous introduction page")
                    }

                    Button(currentStep == pageItems.count - 1 ? "Start Crafting" : "Continue") {
                        if currentStep == pageItems.count - 1 {
                            finishOnboarding()
                        } else {
                            move(to: currentStep + 1)
                        }
                    }
                    .buttonStyle(CraftifyPrimaryButtonStyle())
                    .accessibilityHint(currentStep == pageItems.count - 1
                        ? "Opens your Craftify recipe library"
                        : "Shows the next introduction page")
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: 720)
    }

    private var appMark: CraftifyAppMark {
        CraftifyAppMark()
    }

    private var pagePadding: CGFloat {
        horizontalSizeClass == .regular ? 48 : 24
    }

    private var pageAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.55)
    }

    private func move(to newStep: Int) {
        withAnimation(pageAnimation) {
            step = newStep
        }
    }

    private func finishOnboarding() {
        guard !isFinishing else { return }
        guard !reduceMotion else {
            isFinishing = true
            onDismiss()
            return
        }

        withAnimation(.easeInOut(duration: 0.9)) {
            isFinishing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onDismiss()
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isCurrent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    var body: some View {
        // SwiftUI can evaluate collection content on its asynchronous renderer.
        // Resolve appearance state before those escaping closures are invoked.
        let accentColor = Color.userAccentColor(for: accentColorPreference)
        let highlights = page.highlights

        return ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 18)

                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .stroke(accentColor.opacity(0.22), lineWidth: 1)
                        }

                    Image(systemName: page.symbol)
                        .font(.system(size: 66, weight: .medium))
                        .foregroundStyle(accentColor.gradient)
                }
                .frame(width: 176, height: 176)
                .shadow(color: accentColor.opacity(0.14), radius: 24, y: 12)
                .scaleEffect(isCurrent || reduceMotion ? 1 : 0.94)
                .opacity(isCurrent || reduceMotion ? 1 : 0.7)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: isCurrent)

                VStack(spacing: 10) {
                    Text(page.eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(accentColor)
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(page.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }

                VStack(spacing: 10) {
                    ForEach(highlights) { highlight in
                        OnboardingHighlightRow(
                            highlight: highlight,
                            accentColor: accentColor
                        )
                    }
                }
                .frame(maxWidth: 520)

                if page.title == "Choose your look" {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Image(systemName: "paintpalette.fill")
                                .font(.headline)
                                .foregroundStyle(accentColor)
                                .frame(width: 28)
                            Text("Choose an appearance that feels like yours")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.subheadline.weight(.medium))

                        accentColorPicker
                    }
                    .padding(14)
                    .frame(maxWidth: 520)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Spacer(minLength: 18)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var accentColorPicker: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), alignment: .leading)]
            : [GridItem(.adaptive(minimum: 72), spacing: 12, alignment: .leading)]
        let options = AppAppearanceView.accentColors
        let selection = $accentColorPreference

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options) { option in
                OnboardingAccentColorButton(
                    option: option,
                    selection: selection
                )
            }
        }
        .padding(.leading, 42)
    }
}

private struct OnboardingHighlightRow: View {
    let highlight: OnboardingPage.Highlight
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: highlight.symbol)
                .font(.headline)
                .foregroundStyle(accentColor)
                .frame(width: 28)
            Text(highlight.text)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OnboardingAccentColorButton: View {
    let option: AccentColorOption
    @Binding var selection: String

    private var isSelected: Bool {
        selection == option.id
    }

    var body: some View {
        Button {
            selection = option.id
            HapticFeedback.selection()
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(option.color)
                    .frame(width: 34, height: 34)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                Text(option.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private struct SlidingDoorMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let halfWidth = rect.width / 2
        let travel = halfWidth * progress
        var path = Path()
        path.addRect(CGRect(x: -travel, y: rect.minY, width: halfWidth, height: rect.height))
        path.addRect(CGRect(x: halfWidth + travel, y: rect.minY, width: halfWidth, height: rect.height))
        return path
    }
}

private struct CraftifyBlockGlow: View {
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
        ) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(index == 4 ? 0.18 : 0.08))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .rotationEffect(.degrees(9))
        .accessibilityHidden(true)
    }
}

private struct CraftifyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.craftifyAccentColor) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accent.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: accent.opacity(configuration.isPressed ? 0.12 : 0.25), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
    }
}

private struct OnboardingPage {
    struct Highlight: Identifiable {
        let id = UUID()
        let symbol: String
        let text: String
    }

    let eyebrow: String
    let title: String
    let detail: String
    let symbol: String
    let highlights: [Highlight]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "Welcome",
            title: "Your crafting companion",
            detail: "Find the Minecraft recipe you need without breaking your flow.",
            symbol: "hammer.fill",
            highlights: [
                Highlight(symbol: "square.grid.2x2", text: "Browse a complete, organized recipe library"),
                Highlight(symbol: "sparkles", text: "Discover a fresh selection of Craftify Picks")
            ]
        ),
        OnboardingPage(
            eyebrow: "Ready anywhere",
            title: "Craft anywhere",
            detail: "Your downloaded recipe book stays on this device, so you can keep crafting without an internet connection.",
            symbol: "wifi.slash",
            highlights: [
                Highlight(symbol: "hammer.fill", text: "No signal? Your recipes and images remain ready offline"),
                Highlight(symbol: "icloud.and.arrow.down.fill", text: "Connect now and then to collect new recipes and image updates")
            ]
        ),
        OnboardingPage(
            eyebrow: "Plan your projects",
            title: "Build your chest room",
            detail: "Collect recipes in Minecraft-sized chests so every build has an organized plan.",
            symbol: "shippingbox.fill",
            highlights: [
                Highlight(symbol: "square.grid.3x3.fill", text: "Choose 27-slot or 54-slot chests for each project"),
                Highlight(symbol: "paintbrush.pointed.fill", text: "Personalize every chest with a name and symbol"),
                Highlight(symbol: "icloud.fill", text: "Sync your chest room through iCloud across your devices")
            ]
        ),
        OnboardingPage(
            eyebrow: "Find anything",
            title: "Search in an instant",
            detail: "Find any recipe by its name or by an ingredient you already have.",
            symbol: "magnifyingglass",
            highlights: [
                Highlight(symbol: "line.3.horizontal.decrease.circle", text: "Choose whether to search names, ingredients, or both"),
                Highlight(symbol: "icloud.fill", text: "Recent searches sync through iCloud across your devices")
            ]
        ),
        OnboardingPage(
            eyebrow: "Your Craftify",
            title: "Choose your look",
            detail: "Pick an accent that feels like yours. You can change it whenever you like.",
            symbol: "paintpalette.fill",
            highlights: [
                Highlight(symbol: "circle.hexagongrid.fill", text: "Preview your accent across the whole experience"),
                Highlight(symbol: "accessibility", text: "Designed to stay clear in light and dark appearances")
            ]
        )
    ]
}
