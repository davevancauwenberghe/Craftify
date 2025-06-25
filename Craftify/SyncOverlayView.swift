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
    
    private var cardHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 40 : 24
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.userAccentColor)
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
            .padding(.horizontal, cardHorizontalPadding)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
            .accessibilityValue("Syncing in progress")
            .accessibilityHint("Please wait while the data is being synced")
            .accessibilityAddTraits(.isModal)
        }
    }
}
