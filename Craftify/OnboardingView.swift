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
    let isLoading: Bool
    let errorMessage: String?
    let isFirstLaunch: Bool
    let onDismiss: () -> Void
    let onRetry: () -> Void
    let horizontalSizeClass: UserInterfaceSizeClass?
    
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"
    @State private var currentAccentPreference: String = UserDefaults.standard.string(forKey: "accentColorPreference") ?? "default"
    @State private var isButtonEnabled: Bool
    @State private var buttonScale: CGFloat = 1.0
    @State private var onboardingStep: OnboardingStep = .loading
    @State private var overlayOpacity: CGFloat = 0.0
    @State private var cardOpacity: CGFloat = 0.0
    @State private var cardScale: CGFloat = 0.9
    
    // List of Minecraft crafting tips
    private let craftingTips: [String] = [
        "Did you know? You can craft a pickaxe with just 3 ingots and 2 sticks!",
        "Crafting a furnace requires 8 cobblestones—perfect for smelting ores!",
        "Combine 4 wooden planks to create a crafting table and unlock more recipes!"
    ]
    
    // Adaptive styling based on device size
    private var cardMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 500 : .infinity
    }
    
    private var cardHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 40 : 24
    }
    
    private var titleFont: Font {
        horizontalSizeClass == .regular ? .title : .title2
    }
    
    private var messageFont: Font {
        horizontalSizeClass == .regular ? .title3 : .subheadline
    }
    
    private var buttonFont: Font {
        horizontalSizeClass == .regular ? .title3 : .headline
    }
    
    private var contentSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    enum OnboardingStep {
        case loading
        case options
        case tips
    }
    
    init(title: String, message: String, isLoading: Bool, errorMessage: String?, isFirstLaunch: Bool, onDismiss: @escaping () -> Void, onRetry: @escaping () -> Void, horizontalSizeClass: UserInterfaceSizeClass?) {
        self.title = title
        self.message = message
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.isFirstLaunch = isFirstLaunch
        self.onDismiss = onDismiss
        self.onRetry = onRetry
        self.horizontalSizeClass = horizontalSizeClass
        self._isButtonEnabled = State(initialValue: !isLoading)
    }
    
    var body: some View {
        ZStack {
            // Background overlay with animated opacity
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: overlayOpacity)
            
            switch onboardingStep {
            case .loading:
                loadingView
            case .options:
                optionsView
            case .tips:
                tipsView
            }
        }
        .onAppear {
            // Animate the overlay and card when the view appears
            withAnimation(.easeInOut(duration: 0.5)) {
                overlayOpacity = 0.6
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardOpacity = 1.0
                cardScale = 1.0
            }
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
                            cardOpacity = 0.0
                            cardScale = 0.9
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                onboardingStep = .options
                                cardOpacity = 1.0
                                cardScale = 1.0
                            }
                        }
                    }
                } else {
                    dismissWithAnimation()
                }
            }
        }
        .onChange(of: accentColorPreference) { _, newValue in
            currentAccentPreference = newValue
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: contentSpacing) {
            Text(title)
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(messageFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, cardHorizontalPadding)
            
            if isLoading && errorMessage == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.userAccentColor)
            } else if let error = errorMessage {
                Text(error)
                    .font(messageFont)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, cardHorizontalPadding)
                
                Button(action: {
                    isButtonEnabled = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        cardOpacity = 0.0
                        cardScale = 0.9
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            onboardingStep = .loading
                            cardOpacity = 1.0
                            cardScale = 1.0
                        }
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
                        .padding(.horizontal, cardHorizontalPadding)
                        .scaleEffect(buttonScale)
                        .opacity(isButtonEnabled ? 1.0 : 0.5)
                }
                .accessibilityLabel("Retry Sync")
                .accessibilityHint("Retries fetching recipes from the cloud")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.userAccentColor.opacity(0.4), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 10)
        )
        .padding(.horizontal, cardHorizontalPadding)
        .frame(maxWidth: cardMaxWidth, alignment: .center)
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(message)\(errorMessage != nil ? ", Error: \(errorMessage!)" : isLoading ? ", Loading" : ", Complete")")
        .accessibilityHint("\(errorMessage != nil ? "An error occurred. Tap to retry." : "Please wait while the app fetches your recipes.")")
    }
    
    private var optionsView: some View {
        VStack(spacing: contentSpacing) {
            Text("Ready to Craft!")
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Your recipes are loaded. Would you like to see some crafting tips before you start?")
                .font(messageFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, cardHorizontalPadding)
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cardOpacity = 0.0
                    cardScale = 0.9
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        onboardingStep = .tips
                        cardOpacity = 1.0
                        cardScale = 1.0
                    }
                }
            }) {
                Text("Show Tips")
                    .font(buttonFont)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.userAccentColor)
                    .cornerRadius(10)
                    .padding(.horizontal, cardHorizontalPadding)
                    .scaleEffect(buttonScale)
                    .opacity(isButtonEnabled ? 1.0 : 0.5)
            }
            .accessibilityLabel("Show Crafting Tips")
            .accessibilityHint("View some helpful Minecraft crafting tips")
            
            Button(action: {
                dismissWithAnimation()
            }) {
                Text("Start Crafting")
                    .font(buttonFont)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.userAccentColor)
                    .cornerRadius(10)
                    .padding(.horizontal, cardHorizontalPadding)
                    .scaleEffect(buttonScale)
                    .opacity(isButtonEnabled ? 1.0 : 0.5)
            }
            .accessibilityLabel("Start Crafting")
            .accessibilityHint("Dismiss the onboarding and start using the app")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.userAccentColor.opacity(0.4), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 10)
        )
        .padding(.horizontal, cardHorizontalPadding)
        .frame(maxWidth: cardMaxWidth, alignment: .center)
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ready to Craft!, Your recipes are loaded. Would you like to see some crafting tips before you start?")
        .accessibilityHint("Tap Show Tips to view crafting tips, or Start Crafting to begin using the app.")
    }
    
    private var tipsView: some View {
        VStack(spacing: contentSpacing) {
            Text("Crafting Tips")
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            TabView {
                ForEach(craftingTips, id: \.self) { tip in
                    Text(tip)
                        .font(messageFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, cardHorizontalPadding)
                        .padding(.vertical, 16)
                        .padding(.bottom, 30)
                }
            }
            .tabViewStyle(.page)
            .frame(minHeight: horizontalSizeClass == .regular ? 100 : 80, maxHeight: horizontalSizeClass == .regular ? 150 : 120)
            .padding(.horizontal, cardHorizontalPadding)
            .ignoresSafeArea(edges: .vertical)
            
            Button(action: {
                dismissWithAnimation()
            }) {
                Text("Start Crafting")
                    .font(buttonFont)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.userAccentColor)
                    .cornerRadius(10)
                    .padding(.horizontal, cardHorizontalPadding)
                    .scaleEffect(buttonScale)
                    .opacity(isButtonEnabled ? 1.0 : 0.5)
            }
            .accessibilityLabel("Start Crafting")
            .accessibilityHint("Dismiss the onboarding and start using the app")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.userAccentColor.opacity(0.4), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 10)
        )
        .padding(.horizontal, cardHorizontalPadding)
        .frame(maxWidth: cardMaxWidth, alignment: .center)
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Crafting Tips, Swipe to read tips, Tap Start Crafting to continue")
        .accessibilityHint("Swipe left or right to read Minecraft crafting tips, then tap to start using the app.")
    }
    
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cardOpacity = 0.0
            cardScale = 0.9
        }
        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            overlayOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onDismiss()
        }
    }
}
