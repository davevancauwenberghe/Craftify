//
//  EmptyRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 31/07/2026.
//

import SwiftUI

struct EmptyRecipeView: View {
    var body: some View {
        CraftifyEmptyState(
            symbol: "arrow.triangle.2.circlepath.icloud",
            title: "No Recipes on This Device",
            detail: "Open More and choose Sync Recipes & Images to rebuild your offline recipe book."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background { AppBackground().ignoresSafeArea() }
        .accessibilityLabel("No recipes on this device. Open More and choose Sync Recipes and Images to rebuild your offline recipe book.")
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
