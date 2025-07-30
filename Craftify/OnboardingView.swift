//
//  OnboardingView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 16/05/2025.
//

import SwiftUI

struct OnboardingView: View {
    let title: String
    let message: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let isFirstLaunch: Bool
    let onDismiss: () -> Void
    let onRetry: () -> Void
    let horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var isButtonEnabled: Bool
    @State private var buttonScale: CGFloat = 1.0
    @State private var onboardingStep: OnboardingStep = .loading
    @ScaledMetric(relativeTo: .body) private var contentSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var tabViewMinHeight: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var tabViewMaxHeight: CGFloat = 120

    // List of Minecraft crafting tips
    private let craftingTips: [String] = [
        "This is a test!",
        "Thanks for downloading the Craftify app!",
        "Tips will be added soon."
    ]
    
    // Adaptive styling based on device size
    private var titleFont: Font {
        horizontalSizeClass == .regular ? .title : .title2
    }
    
    private var messageFont: Font {
        horizontalSizeClass == .regular ? .title3 : .subheadline
    }
    
    private var buttonFont: Font {
        horizontalSizeClass == .regular ? .title3 : .headline
    }
    
    enum OnboardingStep {
        case loading
        case options
        case tips
    }
    
    init(title: String, message: String, isLoading: Binding<Bool>, errorMessage: Binding<String?>, isFirstLaunch: Bool, onDismiss: @escaping () -> Void, onRetry: @escaping () -> Void, horizontalSizeClass: UserInterfaceSizeClass?) {
        self.title = title
        self.message = message
        self._isLoading = isLoading
        self._errorMessage = errorMessage
        self.isFirstLaunch = isFirstLaunch
        self.onDismiss = onDismiss
        self.onRetry = onRetry
        self.horizontalSizeClass = horizontalSizeClass
        self._isButtonEnabled = State(initialValue: !isLoading.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: contentSpacing) {
            switch onboardingStep {
            case .loading:
                loadingView
            case .options:
                optionsView
            case .tips:
                tipsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.userAccentColor.opacity(0.4), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .shadow(radius: 10)
        .id(accentColorPreference)
        .onAppear {
            // No overlay or card animations for full-screen
        }
        .onChange(of: isLoading) { _, newValue in
            if !newValue && errorMessage == nil {
                if isFirstLaunch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2)) {
                            isButtonEnabled = true
                            buttonScale = 1.2
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2).delay(0.2)) {
                            buttonScale = 1.0
                            onboardingStep = .options
                        }
                    }
                } else {
                    dismissWithAnimation()
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingStep)
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
    
    private var loadingView: some View {
        VStack(spacing: contentSpacing) {
            Spacer()
            Text(title)
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .accessibilityLabel(title)
            
            Text(message)
                .font(messageFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
                .accessibilityLabel(message)
            
            if isLoading && errorMessage == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.userAccentColor)
                    .accessibilityLabel("Loading recipes")
                    .accessibilityHint("Please wait while the app fetches your recipes")
            } else if let error = errorMessage {
                Text(error)
                    .font(messageFont)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
                    .accessibilityLabel("Error: \(error)")
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isButtonEnabled = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        onboardingStep = .loading
                    }
                    onRetry()
                }) {
                    Text("Retry")
                        .font(buttonFont)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.userAccentColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
                .scaleEffect(buttonScale)
                .opacity(isButtonEnabled ? 1.0 : 0.5)
                .disabled(!isButtonEnabled)
                .accessibilityLabel("Retry Sync")
                .accessibilityHint("Retries fetching recipes from the cloud")
            }
            Spacer()
        }
        .padding(.vertical, paddingVertical)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
    }
    
    private var optionsView: some View {
        VStack(spacing: contentSpacing) {
            Spacer()
            Text("Ready to Craft!")
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .accessibilityLabel("Ready to Craft")
            
            Text("Your recipes are loaded. Would you like to see some crafting tips before you start?")
                .font(messageFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
                .accessibilityLabel("Your recipes are loaded")
                .accessibilityHint("Choose to view crafting tips or start using the app")
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onboardingStep = .tips
                }
            }) {
                Text("Show Tips")
                    .font(buttonFont)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.userAccentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
            .scaleEffect(buttonScale)
            .opacity(isButtonEnabled ? 1.0 : 0.5)
            .accessibilityLabel("Show Crafting Tips")
            .accessibilityHint("View some helpful Minecraft crafting tips")
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismissWithAnimation()
            }) {
                Text("Start Crafting")
                    .font(buttonFont)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.userAccentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
            .scaleEffect(buttonScale)
            .opacity(isButtonEnabled ? 1.0 : 0.5)
            .accessibilityLabel("Start Crafting")
            .accessibilityHint("Dismiss the onboarding and start using the app")
            Spacer()
        }
        .padding(.vertical, paddingVertical)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
    }
    
    private var tipsView: some View {
        VStack(spacing: contentSpacing) {
            Spacer()
            Text("Crafting Tips")
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .accessibilityLabel("Crafting Tips")
            
            TabView {
                ForEach(craftingTips.indices, id: \.self) { index in
                    Text(craftingTips[index])
                        .font(messageFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
                        .padding(.vertical, paddingVertical)
                        .padding(.bottom, paddingVertical * 1.5)
                        .accessibilityLabel("Crafting Tip \(index + 1) of \(craftingTips.count)")
                        .accessibilityValue(craftingTips[index])
                        .accessibilityHint("Swipe left or right to read more tips")
                }
            }
            .tabViewStyle(.page)
            .frame(minHeight: horizontalSizeClass == .regular ? tabViewMinHeight * 1.25 : tabViewMinHeight, maxHeight: horizontalSizeClass == .regular ? tabViewMaxHeight * 1.25 : tabViewMaxHeight)
            .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
            .ignoresSafeArea(edges: .vertical)
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismissWithAnimation()
            }) {
                Text("Start Crafting")
                    .font(buttonFont)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.userAccentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? paddingHorizontal * 1.67 : paddingHorizontal)
            .scaleEffect(buttonScale)
            .opacity(isButtonEnabled ? 1.0 : 0.5)
            .accessibilityLabel("Start Crafting")
            .accessibilityHint("Dismiss the onboarding and start using the app")
            Spacer()
        }
        .padding(.vertical, paddingVertical)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            // No overlay or card animations for full-screen
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDismiss()
        }
    }
}
