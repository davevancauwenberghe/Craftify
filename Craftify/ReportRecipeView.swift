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
    @State private var recipeErrorName: String = ""
    @State private var recipeErrorCategory: String = ""
    @State private var additionalInfo: String = ""
    @State private var isLoadingReports: Bool = false
    @State private var reportToDelete: RecipeReport?
    @State private var showDeleteConfirmation: Bool = false
    @State private var submissionState: SubmissionState = .idle
    @State private var showSubmissionPopup: Bool = false
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

    enum SubmissionState: Equatable {
        case idle
        case submitting
        case success
        case failure(String)

        static func == (lhs: SubmissionState, rhs: SubmissionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.submitting, .submitting):
                return true
            case (.success, .success):
                return true
            case (.failure(let lhsError), .failure(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }

    private var isFormIncomplete: Bool {
        if reportType == .missingRecipe {
            return recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   selectedCategory.isEmpty ||
                   additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return recipeErrorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   recipeErrorCategory.isEmpty ||
                   additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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
                .stroke(Color.userAccentColor, lineWidth: 2)
        )
        .pickerStyle(.menu)
        .accessibilityLabel("Category")
        .accessibilityHint("Select the category of the missing recipe")
    }

    private var recipeErrorCategoryPicker: some View {
        Picker("Category", selection: $recipeErrorCategory) {
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
                .stroke(Color.userAccentColor, lineWidth: 2)
        )
        .pickerStyle(.menu)
        .accessibilityLabel("Category")
        .accessibilityHint("Select the category of the recipe with an error")
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
                    .stroke(Color.userAccentColor, lineWidth: 2)
            )
            .onChange(of: recipeName) { _, newValue in
                if newValue.count > maxRecipeNameLength {
                    recipeName = String(newValue.prefix(maxRecipeNameLength))
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
                    .stroke(Color.userAccentColor, lineWidth: 2)
            )
            .onChange(of: recipeErrorName) { _, newValue in
                if newValue.count > maxRecipeNameLength {
                    recipeErrorName = String(newValue.prefix(maxRecipeNameLength))
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
                    .stroke(Color.userAccentColor, lineWidth: 2)
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
                                // Category Picker for Recipe Error
                                recipeErrorCategoryPicker

                                // Recipe Name for Recipe Error
                                recipeErrorNameTextField
                            }

                            // Additional Information
                            additionalInfoView

                            // Submit Button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                submitReport()
                            }) {
                                Text("Submit Report")
                                    .font(horizontalSizeClass == .regular ? .title3 : .headline)
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
                                    .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 24)
                                    .background(isFormIncomplete ? Color.userAccentColor.opacity(0.5) : Color.userAccentColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(isFormIncomplete)
                            .accessibilityLabel("Submit Report")
                            .accessibilityHint(isFormIncomplete ? "Submit Report button is disabled. Please fill in all required fields: recipe name, category, and additional information." : "Submits the report")
                        } else {
                            // My Reports Section
                            if dataManager.submittedReports.isEmpty {
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
                                // Refresh Status Button
                                Button(action: {
                                    fetchReportStatuses()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Refresh Status")
                                    }
                                    .font(.headline)
                                    .foregroundColor(Color.userAccentColor)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .accessibilityLabel("Refresh Status")
                                .accessibilityHint("Refreshes the status of your submitted reports")

                                if isLoadingReports {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(Color.userAccentColor)
                                        .accessibilityLabel("Loading reports")
                                } else {
                                    ForEach(dataManager.submittedReports.sorted(by: { $0.timestamp > $1.timestamp })) { report in
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Report Type and Status
                                            HStack {
                                                Text(report.reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error")
                                                    .font(.headline)
                                                    .foregroundColor(Color.userAccentColor)
                                                Spacer()
                                                Text(report.status)
                                                    .font(.subheadline)
                                                    .foregroundColor(report.status == "Pending" ? .orange : .green)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }

                                            // Recipe Name
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Recipe Name")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text(report.recipeName)
                                                    .font(.body)
                                            }

                                            // Category
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Category")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text(report.category)
                                                    .font(.body)
                                            }

                                            // Description
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Details")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text(report.description)
                                                    .font(.body)
                                            }

                                            // Submission Date
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Submitted")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text(formattedDate(report.timestamp))
                                                    .font(.body)
                                            }

                                            // Delete Button (Accessibility Fallback)
                                            Button(action: {
                                                reportToDelete = report
                                                showDeleteConfirmation = true
                                            }) {
                                                Text("Delete Report")
                                                    .font(.subheadline)
                                                    .foregroundColor(.red)
                                                    .padding(.vertical, 8)
                                                    .frame(maxWidth: .infinity, alignment: .center)
                                            }
                                            .accessibilityLabel("Delete this report")
                                            .accessibilityHint("Deletes the selected report")
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                reportToDelete = report
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Report: \(report.reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error") for \(report.recipeName), Category: \(report.category), Status: \(report.status), Details: \(report.description), Submitted: \(formattedDate(report.timestamp))")
                                        .accessibilityHint("Swipe to delete this report or tap the delete button")
                                    }
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

                // Submission Popup
                if showSubmissionPopup {
                    SubmissionPopup(
                        state: submissionState,
                        onDismiss: {
                            showSubmissionPopup = false
                            if case .success = submissionState {
                                resetForm()
                            }
                            submissionState = .idle
                        }
                    )
                    .animation(.easeInOut, value: showSubmissionPopup)
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert("Delete Report", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let report = reportToDelete {
                        deleteReport(report)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this report? This action cannot be undone.")
            }
            .onAppear {
                if viewMode == .myReports {
                    fetchReportStatuses()
                }
            }
            .onChange(of: viewMode) { _, newValue in
                if newValue == .myReports {
                    fetchReportStatuses()
                }
            }
            .onChange(of: reportType) { _, _ in
                resetForm()
            }
        }
    }

    // MARK: - Submission Popup View
    struct SubmissionPopup: View {
        let state: SubmissionState
        let onDismiss: () -> Void

        var body: some View {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if state == .submitting {
                            // Don't dismiss while submitting
                        } else {
                            onDismiss()
                        }
                    }

                VStack(spacing: 20) {
                    switch state {
                    case .submitting:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.userAccentColor)
                            .scaleEffect(1.5)
                        Text("Sending report...")
                            .font(.headline)
                            .foregroundColor(.primary)

                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.green)
                        Text("Thanks for sending the report!")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                    case .failure(let errorMessage):
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.red)
                        Text("Failed to submit report")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    case .idle:
                        EmptyView()
                    }

                    if state != .submitting {
                        Button(action: onDismiss) {
                            Text("OK")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.userAccentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)
                .frame(maxWidth: 300)
                .padding()
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func resetForm() {
        recipeName = ""
        selectedCategory = ""
        recipeErrorName = ""
        recipeErrorCategory = ""
        additionalInfo = ""
    }

    private func submitReport() {
        if isFormIncomplete {
            return
        }

        submissionState = .submitting
        showSubmissionPopup = true

        dataManager.submitRecipeReport(
            reportType: reportType.rawValue,
            recipeName: reportType == .missingRecipe ? recipeName : recipeErrorName,
            category: reportType == .missingRecipe ? selectedCategory : recipeErrorCategory,
            recipeID: nil,
            description: additionalInfo
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.submissionState = .success
                case .failure(let error):
                    self.submissionState = .failure("Failed to submit report: \(error.localizedDescription)")
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
            DispatchQueue.main.async {
                if success {
                    self.reportToDelete = nil
                } else {
                    self.dataManager.errorMessage = "Failed to delete report. Please try again."
                }
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
