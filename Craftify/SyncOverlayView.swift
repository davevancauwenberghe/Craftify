//
//  SyncOverlayView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 19/05/2025.
//

import SwiftUI

struct SyncOverlayView: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    let message: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 100 : 40
    }

    private var cardCornerRadius: CGFloat {
        20
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.userAccentColor)
                    .scaleEffect(1.5) // Slightly larger for visibility

                Text(message)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
            }
            .padding(24)
            .background(.ultraThinMaterial) // Frosted glass blur (iOS 15+)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, cardHorizontalPadding)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(message), Syncing in progress")
            .accessibilityHint("Please wait while data is syncing. This overlay will dismiss automatically when complete.")
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3))) // Smooth fade-in/out
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
