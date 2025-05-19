//
//  ReportRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/03/2025.
//

import SwiftUI
import UIKit

struct ReportRecipeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewMode: ViewMode = .submitReport
    @State private var reportType: ReportType = .missingRecipe
    @State private var recipeName: String = ""
    @State private var selectedCategory: String = ""
    @State private var recipeErrorName: String = "" // Replaced selectedRecipe with a String
    @State private var additionalInfo: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var showValidationErrors: Bool = false
    @State private var isLoadingReports: Bool = false
    @State private var reportToDelete: RecipeReport?
    @State private var showDeleteConfirmation: Bool = false
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"

    private let categories: [String] = [
        "Beds", "Crafting", "Food", "Lighting", "Planks",
        "Smelting", "Storage", "Tools", "Transportation", "Utilities", "Not listed"
    ]
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 1000
    private var fieldHeight: CGFloat {
        horizontalSizeClass == .regular ? 48 : 44
    }

    enum ViewMode: String {
        case submitReport = "Submit Report"
        case myReports = "My Reports"
    }

    enum ReportType: String {
        case missingRecipe = "Report Missing Recipe"
        case recipeError = "Report Recipe Error"
    }

    private var validationErrorMessage: String {
        var missingFields: [String] = []
        if reportType == .missingRecipe {
            if selectedCategory.isEmpty {
                missingFields.append("Category")
            }
            if recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingFields.append("Recipe Name")
            }
        } else {
            if recipeErrorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingFields.append("Recipe Name")
            }
        }
        if additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missingFields.append("Additional Information")
        }
        if missingFields.isEmpty {
            return ""
        }
        return "Please fill in the following: \(missingFields.joined(separator: ", "))."
    }

    private var isFormIncomplete: Bool {
        if reportType == .missingRecipe {
            return recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   selectedCategory.isEmpty ||
                   additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return recipeErrorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Computed Properties for Views

    private var categoryBorderColor: Color {
        showValidationErrors && selectedCategory.isEmpty ? Color.red : Color.userAccentColor
    }

    private var recipeNameBorderColor: Color {
        showValidationErrors && recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red : Color.userAccentColor
    }

    private var recipeErrorNameBorderColor: Color {
        showValidationErrors && recipeErrorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red : Color.userAccentColor
    }

    private var additionalInfoBorderColor: Color {
        showValidationErrors && additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red : Color.userAccentColor
    }

    @ViewBuilder
    private var categoryPickerContent: some View {
        Text("Select category").tag("")
        ForEach(categories, id: \.self) { cat in
            Text(cat).tag(cat)
        }
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $selectedCategory) {
            categoryPickerContent
        }
        .font(.body)
        .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
        .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
        .frame(maxWidth: .infinity, minHeight: fieldHeight)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(categoryBorderColor, lineWidth: 2)
        )
        .pickerStyle(.menu)
        .accessibilityLabel("Category")
        .accessibilityHint("Select the category of the missing recipe")
    }

    private var recipeNameTextField: some View {
        TextField("Recipe name", text: $recipeName)
            .font(.body)
            .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
            .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: fieldHeight)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(recipeNameBorderColor, lineWidth: 2)
            )
            .onChange(of: recipeName) { _, newValue in
                if newValue.count > maxRecipeNameLength {
                    recipeName = String(newValue.prefix(maxRecipeNameLength))
                }
                if showValidationErrors && !isFormIncomplete {
                    showValidationErrors = false
                }
            }
            .accessibilityLabel("Recipe name")
            .accessibilityHint("Enter the name of the missing recipe")
    }

    private var recipeErrorNameTextField: some View {
        TextField("Recipe name", text: $recipeErrorName)
            .font(.body)
            .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
            .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: fieldHeight)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(recipeErrorNameBorderColor, lineWidth: 2)
            )
            .onChange(of: recipeErrorName) { _, newValue in
                if newValue.count > maxRecipeNameLength {
                    recipeErrorName = String(newValue.prefix(maxRecipeNameLength))
                }
                if showValidationErrors && !isFormIncomplete {
                    showValidationErrors = false
                }
            }
            .accessibilityLabel("Recipe name")
            .accessibilityHint("Enter the name of the recipe with an error")
    }

    private var additionalInfoView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Text("Add details...")
                    .font(horizontalSizeClass == .regular ? .callout : .subheadline)
                    .foregroundColor(.secondary.opacity(additionalInfo.isEmpty ? 0.7 : 0))
                    .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
                    .padding(.vertical, horizontalSizeClass == .regular ? 18 : 14)
                    .onChange(of: additionalInfo) { _, _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // Opacity updated via binding
                        }
                        if showValidationErrors && !isFormIncomplete {
                            showValidationErrors = false
                        }
                    }
                TextEditorRepresentable(text: $additionalInfo)
                    .font(.body)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
                    .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight * 2)
                    .onChange(of: additionalInfo) { _, newValue in
                        if newValue.count > maxAdditionalInfoLength {
                            additionalInfo = String(newValue.prefix(maxAdditionalInfoLength))
                        }
                    }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(additionalInfoBorderColor, lineWidth: 2)
            )
            .accessibilityLabel("Additional Information")
            .accessibilityHint("Enter details about the missing recipe or error")
            .accessibilityValue(additionalInfo.isEmpty ? "No details entered" : additionalInfo)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    VStack(spacing: horizontalSizeClass == .regular ? 24 : 16) {
                        // View Mode Picker
                        Picker("View Mode", selection: $viewMode) {
                            Text(ViewMode.submitReport.rawValue).tag(ViewMode.submitReport)
                            Text(ViewMode.myReports.rawValue).tag(ViewMode.myReports)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
                        .accessibilityLabel("View Mode")
                        .accessibilityHint("Select whether to submit a new report or view your reports")

                        if viewMode == .submitReport {
                            // Report Type Picker
                            Picker("Report Type", selection: $reportType) {
                                Text(ReportType.missingRecipe.rawValue).tag(ReportType.missingRecipe)
                                Text(ReportType.recipeError.rawValue).tag(ReportType.recipeError)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
                            .accessibilityLabel("Report Type")
                            .accessibilityHint("Select whether to report a missing recipe or an error in an existing recipe")

                            // Conditional Fields Based on Report Type
                            if reportType == .missingRecipe {
                                // Category Picker for Missing Recipe
                                categoryPicker

                                // Recipe Name for Missing Recipe
                                recipeNameTextField
                            } else {
                                // Recipe Name for Recipe Error
                                recipeErrorNameTextField
                            }

                            // Additional Information
                            additionalInfoView

                            // Validation Error Message
                            if showValidationErrors && !validationErrorMessage.isEmpty {
                                Text(validationErrorMessage)
                                    .font(horizontalSizeClass == .regular ? .subheadline : .footnote)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityLabel("Validation error: \(validationErrorMessage)")
                                    .accessibilityHint("Fill in the required fields to proceed")
                            }

                            // Submit Button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                submitReport()
                            }) {
                                HStack {
                                    if isSubmitting {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Color.userAccentColor)
                                            .padding(.trailing, 8)
                                    }
                                    Text("Submit Report")
                                        .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                                .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 24)
                                .background(isFormIncomplete ? Color.userAccentColor.opacity(0.5) : Color.userAccentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(isFormIncomplete || isSubmitting)
                            .accessibilityLabel("Submit Report")
                            .accessibilityHint("Submits the report")
                        } else {
                            // My Reports Section
                            if isLoadingReports {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(Color.userAccentColor)
                                    .accessibilityLabel("Loading reports")
                            } else if dataManager.submittedReports.isEmpty {
                                VStack(spacing: 16) {
                                    Text("No Reports Found")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("You haven’t submitted any reports yet.")
                                        .font(horizontalSizeClass == .regular ? .body : .subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("No reports found. You haven’t submitted any reports yet.")
                            } else {
                                ForEach(dataManager.submittedReports) { report in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(report.reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error")
                                                .font(.headline)
                                                .foregroundColor(Color.userAccentColor)
                                            Spacer()
                                            Text(report.status)
                                                .font(.subheadline)
                                                .foregroundColor(report.status == "Pending" ? .orange : .green)
                                        }
                                        Text("Recipe: \(report.recipeName)")
                                            .font(.body)
                                        Text("Category: \(report.category)")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        Text("Details: \(report.description)")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        Text("Submitted: \(formattedDate(report.timestamp))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            reportToDelete = report
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Report: \(report.reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error") for \(report.recipeName), Category: \(report.category), Status: \(report.status), Details: \(report.description), Submitted: \(formattedDate(report.timestamp))")
                                    .accessibilityHint("Swipe to delete this report")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 600 : 400)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                    .padding(.vertical, horizontalSizeClass == .regular ? 32 : 24)
                }
                .id(accentColorPreference)
                .safeAreaInset(edge: .top, content: { Color.clear.frame(height: 0) })
                .safeAreaInset(edge: .bottom, content: { Color.clear.frame(height: 0) })
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert(isPresented: $showConfirmation) {
                Alert(
                    title: Text("Report Submitted"),
                    message: Text("Thank you for your report! We’ll review your submission."),
                    dismissButton: .default(Text("OK")) {
                        resetForm()
                    }
                )
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Report"),
                    message: Text("Are you sure you want to delete this report? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let report = reportToDelete {
                            deleteReport(report)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                fetchReportStatuses()
            }
            .onChange(of: viewMode) { _, _ in
                if viewMode == .myReports {
                    fetchReportStatuses()
                }
            }
            .onChange(of: reportType) { _, _ in
                resetForm()
            }
            .onChange(of: selectedCategory) { _, _ in
                if showValidationErrors && !isFormIncomplete {
                    showValidationErrors = false
                }
            }
            .onChange(of: recipeErrorName) { _, _ in
                if showValidationErrors && !isFormIncomplete {
                    showValidationErrors = false
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func resetForm() {
        recipeName = ""
        selectedCategory = ""
        recipeErrorName = ""
        additionalInfo = ""
        showValidationErrors = false
    }

    private func submitReport() {
        if isFormIncomplete {
            showValidationErrors = true
            return
        }

        isSubmitting = true

        dataManager.submitRecipeReport(
            reportType: reportType.rawValue,
            recipeName: reportType == .missingRecipe ? recipeName : recipeErrorName,
            category: reportType == .missingRecipe ? selectedCategory : "Not specified", // Default category for error reports
            recipeID: nil, // No recipeID since we're not selecting from a list
            description: additionalInfo
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                switch result {
                case .success:
                    self.showConfirmation = true
                case .failure:
                    // Error message is already set by DataManager
                    break
                }
            }
        }
    }

    private func fetchReportStatuses() {
        isLoadingReports = true
        dataManager.fetchRecipeReportStatuses {
            DispatchQueue.main.async {
                self.isLoadingReports = false
            }
        }
    }

    private func deleteReport(_ report: RecipeReport) {
        dataManager.deleteRecipeReport(report) { success in
            if success {
                self.reportToDelete = nil
            }
        }
    }
}

struct TextEditorRepresentable: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor.secondarySystemGroupedBackground
        textView.text = text
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.backgroundColor = UIColor.secondarySystemGroupedBackground
        uiView.font = .preferredFont(forTextStyle: .body)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextEditorRepresentable

        init(_ parent: TextEditorRepresentable) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
    }
}
