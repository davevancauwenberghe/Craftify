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
    let horizontalSizeClass: UserInterfaceSizeClass?

    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .id(accentColorPreference)
        .tint(Color.userAccentColor)
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
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [Color.userAccentColor.opacity(0.22), .clear, Color.userAccentColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.userAccentColor.opacity(0.12))
                .frame(width: horizontalSizeClass == .regular ? 520 : 330)
                .blur(radius: 2)
                .offset(x: 160, y: -300)
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
                .tint(Color.userAccentColor)
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
                    ProgressView(
                        value: Double(downloaded),
                        total: Double(max(displayedTotal, 1))
                    )
                    .progressViewStyle(.linear)
                    .accessibilityHidden(true)
                    Text("Downloading recipes \(downloaded) / \(displayedTotal)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel(
                            "\(downloaded) of \(displayedTotal) recipes downloaded"
                        )
                } else {
                    Text("Downloading recipes… \(downloaded)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(downloaded) recipes downloaded")
                }

            case .preparingImages(let prepared, let total):
                ProgressView(
                    value: Double(total == 0 ? 1 : prepared),
                    total: Double(max(total, 1))
                )
                .progressViewStyle(.linear)
                .accessibilityHidden(true)
                Text("Preparing images \(prepared) / \(total)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(prepared) of \(total) images prepared")
            }
        }
        .frame(maxWidth: 320)
        .animation(.easeInOut(duration: 0.25), value: dataManager.recipeBookLoadingPhase)
    }

    private var onboardingPages: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page, isCurrent: step == index)
                        .tag(index)
                        .padding(.horizontal, pagePadding)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityLabel("Craftify introduction")
            .accessibilityValue("Page \(step + 1) of \(pages.count): \(pages[step].title)")

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == step ? Color.userAccentColor : Color.secondary.opacity(0.22))
                            .frame(width: index == step ? 28 : 8, height: 8)
                            .animation(pageAnimation, value: step)
                    }
                }
                .accessibilityHidden(true)

                HStack(spacing: 12) {
                    if step > 0 {
                        Button("Back") {
                            move(to: step - 1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityHint("Shows the previous introduction page")
                    }

                    Button(step == pages.count - 1 ? "Start Crafting" : "Continue") {
                        if step == pages.count - 1 {
                            finishOnboarding()
                        } else {
                            move(to: step + 1)
                        }
                    }
                    .buttonStyle(CraftifyPrimaryButtonStyle())
                    .accessibilityHint(step == pages.count - 1
                        ? "Opens your Craftify recipe library"
                        : "Shows the next introduction page")
                }
            }
            .padding(.horizontal, pagePadding)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: 720)
    }

    private var appMark: AppMark {
        AppMark()
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
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 18)

                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .stroke(Color.userAccentColor.opacity(0.22), lineWidth: 1)
                        }

                    Image(systemName: page.symbol)
                        .font(.system(size: 66, weight: .medium))
                        .foregroundStyle(Color.userAccentColor.gradient)
                }
                .frame(width: 176, height: 176)
                .shadow(color: Color.userAccentColor.opacity(0.14), radius: 24, y: 12)
                .scaleEffect(isCurrent || reduceMotion ? 1 : 0.94)
                .opacity(isCurrent || reduceMotion ? 1 : 0.7)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: isCurrent)

                VStack(spacing: 10) {
                    Text(page.eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.userAccentColor)
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
                    ForEach(page.highlights) { highlight in
                        HStack(spacing: 14) {
                            Image(systemName: highlight.symbol)
                                .font(.headline)
                                .foregroundStyle(Color.userAccentColor)
                                .frame(width: 28)
                            Text(highlight.text)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .frame(maxWidth: 520)

                if page.title == "Choose your look" {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Image(systemName: "paintpalette.fill")
                                .font(.headline)
                                .foregroundStyle(Color.userAccentColor)
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

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppAppearanceView.accentColors) { option in
                accentColorButton(for: option)
            }
        }
        .padding(.leading, 42)
    }

    private func accentColorButton(for option: AccentColorOption) -> some View {
        let isSelected = accentColorPreference == option.id

        return Button {
            selectAccentColor(option.id)
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

    private func selectAccentColor(_ id: String) {
        accentColorPreference = id
        HapticFeedback.selection()
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

private struct AppMark: View {
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size / 4, style: .continuous)
                .fill(Color.userAccentColor.gradient)
            Image(systemName: "hammer.fill")
                .font(.system(size: size * 0.43, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.userAccentColor.opacity(0.28), radius: 16, y: 8)
        .accessibilityHidden(true)
    }

}

private struct CraftifyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.userAccentColor.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.userAccentColor.opacity(configuration.isPressed ? 0.12 : 0.25), radius: 10, y: 5)
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
                Highlight(symbol: "hammer.fill", text: "No signal? No crafting-table crisis—your recipes and images remain ready offline"),
                Highlight(symbol: "icloud.and.arrow.down.fill", text: "Connect now and then to collect new recipes and image updates")
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
