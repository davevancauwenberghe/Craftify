//
//  CraftifyDesignSystem.swift
//  Craftify
//
//  Shared visual language for the Craftify experience.
//

import SwiftUI

private struct CraftifyAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.userAccentColor
}

extension EnvironmentValues {
    var craftifyAccentColor: Color {
        get { self[CraftifyAccentColorKey.self] }
        set { self[CraftifyAccentColorKey.self] = newValue }
    }
}

enum CraftifyLayout {
    static let contentMaxWidth: CGFloat = 1_180

    static func pagePadding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 28 : 16
    }

    static func adaptiveColumns(
        minimum: CGFloat,
        maximum: CGFloat = 440,
        spacing: CGFloat = 16,
        dynamicTypeSize: DynamicTypeSize
    ) -> [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: spacing)]
    }
}

/// The app-wide canvas. The restrained 3×3 block motifs reference the
/// crafting grid without turning every screen into a Minecraft texture.
struct AppBackground: View {
    @Environment(\.craftifyAccentColor) private var accent
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            LinearGradient(
                colors: [
                    accent.opacity(reduceTransparency ? 0.12 : (colorScheme == .dark ? 0.20 : 0.16)),
                    accent.opacity(reduceTransparency ? 0.035 : 0.07),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geometry in
                CraftifyBlockMotif()
                    .frame(width: min(geometry.size.width * 0.52, 340))
                    .rotationEffect(.degrees(-8))
                    .offset(x: geometry.size.width * 0.60, y: -38)

                CraftifyBlockMotif()
                    .frame(width: min(geometry.size.width * 0.34, 220))
                    .rotationEffect(.degrees(10))
                    .offset(x: -70, y: geometry.size.height * 0.72)
            }
            .opacity(reduceTransparency ? 0.24 : 0.48)
        }
        .accessibilityHidden(true)
    }
}

private struct CraftifyBlockMotif: View {
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
            spacing: 7
        ) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(index.isMultiple(of: 2) ? 0.095 : 0.045))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

struct CraftifyIconTile: View {
    let symbol: String
    var size: CGFloat = 56
    var destructive = false
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.40, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                destructive ? Color.red.gradient : accent.gradient,
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .shadow(
                color: (destructive ? Color.red : accent).opacity(0.20),
                radius: 10,
                y: 5
            )
            .accessibilityHidden(true)
    }
}

struct CraftifyAppMark: View {
    var size: CGFloat = 88
    @Environment(\.craftifyAccentColor) private var accent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(accent.gradient)
            Image(systemName: "hammer.fill")
                .font(.system(size: size * 0.43, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: accent.opacity(0.24), radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}

struct CraftifyHero: View {
    let eyebrow: String?
    let title: String
    let detail: String
    let symbol: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.craftifyAccentColor) private var accent

    init(eyebrow: String? = nil, title: String, detail: String, symbol: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                ViewThatFits(in: .horizontal) {
                    horizontalContent
                    verticalContent
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .craftifyCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }

    private var horizontalContent: some View {
        HStack(spacing: 18) {
            CraftifyIconTile(symbol: symbol, size: 64)
            copy(alignment: .leading)
        }
    }

    private var verticalContent: some View {
        VStack(spacing: 14) {
            CraftifyIconTile(symbol: symbol, size: 64)
            copy(alignment: .center)
        }
    }

    private func copy(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 5) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(accent)
            }
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(alignment)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

struct CraftifySectionHeader: View {
    let title: String
    var detail: String?
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let symbol {
                Label(title, systemImage: symbol)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            } else {
                Text(title)
                    .font(.title3.bold())
            }

            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct CraftifyEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 13) {
            CraftifyIconTile(symbol: symbol, size: 68)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 28)
        .padding(.vertical, 34)
        .craftifyCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }
}

struct CraftifyStatusPill: View {
    let title: String
    let symbol: String
    var tint: Color?
    @Environment(\.craftifyAccentColor) private var accent

    init(title: String, symbol: String, tint: Color? = nil) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        let resolvedTint = tint ?? accent

        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(resolvedTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(resolvedTint.opacity(0.12), in: Capsule())
    }
}

private struct CraftifyCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.craftifyAccentColor) private var accent

    func body(content: Content) -> some View {
        content
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        accent.opacity(contrast == .increased ? 0.42 : 0.16),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
    }
}

private struct CraftifyAccentCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.craftifyAccentColor) private var accent

    func body(content: Content) -> some View {
        content
            .background {
                AppBackground()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        accent.opacity(contrast == .increased ? 0.48 : 0.20),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
    }
}

private struct CraftifyFloatingSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    private var accent: Color {
        Color.userAccentColor(for: accentColorPreference)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(accent.opacity(0.08)),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

private struct CraftifyNavigationBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}

private struct CraftifyPageModifier: ViewModifier {
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

    func body(content: Content) -> some View {
        let accent = Color.userAccentColor(for: accentColorPreference)

        content
            .background {
                AppBackground()
                    .environment(\.craftifyAccentColor, accent)
                    .ignoresSafeArea()
            }
            .tint(accent)
            .environment(\.craftifyAccentColor, accent)
            .modifier(CraftifyNavigationBarModifier())
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

extension View {
    func craftifyCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(CraftifyCardModifier(cornerRadius: cornerRadius))
    }

    func craftifyAccentCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(CraftifyAccentCardModifier(cornerRadius: cornerRadius))
    }

    func craftifyFloatingSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(CraftifyFloatingSurfaceModifier(cornerRadius: cornerRadius))
    }

    func craftifyNavigationBar() -> some View {
        modifier(CraftifyNavigationBarModifier())
    }

    func craftifyPage() -> some View {
        modifier(CraftifyPageModifier())
    }

    func craftifyContentWidth(_ maximum: CGFloat = CraftifyLayout.contentMaxWidth) -> some View {
        frame(maxWidth: maximum)
            .frame(maxWidth: .infinity)
    }

    func craftifyButtonBorder(cornerRadius: CGFloat = 16) -> some View {
        buttonBorderShape(.roundedRectangle(radius: cornerRadius))
    }
}
