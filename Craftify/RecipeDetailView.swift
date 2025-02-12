//
//  RecipeDetailView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/02/2025.
//

import SwiftUI
import Combine
import CloudKit

struct RecipeDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    let recipe: Recipe
    @Binding var navigationPath: NavigationPath
    @State private var selectedDetail: String?
    @State private var animateHeart = false
    @State private var isShareSheetPresented = false  // Controls share sheet presentation

    // Compose a shareable text for the recipe.
    var shareText: String {
        "Check out this recipe: \(recipe.name). Ingredients: \(recipe.ingredients.joined(separator: ", ")). Output: x\(recipe.output)."
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // Crafting Grid & Output Side by Side
            HStack(alignment: .center, spacing: 16) {
                // 3x3 Crafting Grid for ingredients.
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            (index < recipe.ingredients.count && !recipe.ingredients[index].isEmpty)
                                            ? Color(UIColor.systemGray5)
                                            : Color(UIColor.systemGray6)
                                        )
                                        .frame(width: 70, height: 70)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    if index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty {
                                        Image(recipe.ingredients[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                                .onTapGesture {
                                    guard index < recipe.ingredients.count, !recipe.ingredients[index].isEmpty else { return }
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        // Always set the pop-up to the tapped value.
                                        selectedDetail = recipe.ingredients[index]
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Arrow indicator between grid and output.
                Image(systemName: "arrow.right")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 60)
                
                // Output Item styled similarly to grid cells.
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        Image(recipe.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                    }
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDetail = recipe.name
                        }
                    }
                    
                    Text("x\(recipe.output)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Display tapped detail (ingredient or output) if available.
            if let detail = selectedDetail {
                Text(detail)
                    .font(.title2)
                    .bold()
                    .padding()
                    .background(Color(UIColor.systemGray3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedDetail)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Share button: placed on the leading side.
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    isShareSheetPresented = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            // Favorite (heart) button: placed on the trailing side.
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                        animateHeart = true
                    }
                    
                    dataManager.toggleFavorite(recipe: recipe)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            animateHeart = false
                        }
                    }
                }) {
                    Image(systemName: dataManager.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                        .font(.title2)
                        .scaleEffect(animateHeart ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: animateHeart)
                }
            }
        }
        // Present the share sheet when isShareSheetPresented is true.
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(activityItems: [shareText])
        }
        // Overlay to display the recipe category at the bottom.
        .overlay(
            Group {
                if !recipe.category.isEmpty {
                    Text("Category: \(recipe.category)")
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                }
            },
            alignment: .bottom
        )
    }
}

// A simple ShareSheet view to wrap UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update.
    }
}

