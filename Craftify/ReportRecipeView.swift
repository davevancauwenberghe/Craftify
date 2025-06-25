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
    @State private var reports: [RecipeReport] = []
    @State private var isLoadingReports: Bool = false
    @State private var reportToDelete: RecipeReport?
    @State private var showDeleteConfirmation: Bool = false
    @State private var submissionState: SubmissionState = .idle
    @State private var showSubmissionPopup: Bool = false
    @State private var lastSubmissionTime: Date?
    @State private var submissionCooldownMessage: String?
    @State private var submissionCooldownTimer: Timer?
    @State private var showDeleteConfirmationPopup: Bool = false
    @State private var deleteConfirmationMessage: String?
    @State private var cachedSortedReports: [RecipeReport] = []
    @AppStorage("accentColorPreference") private var accentColorPreference: String = "default"

    private let categories: [String] = [
        "Beds", "Crafting", "Consumables", "Lighting", "Planks",
        "Smelting", "Storage", "Tools", "Transportation", "Utilities", "Not listed"
    ]
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 500
    private let submissionCooldownDuration: TimeInterval = 30
    private let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ")
    private var fieldHeight: CGFloat {
        horizontalSizeClass == .regular ? 48 : 44
    }
    private var remainingSubmissionCooldown: Int {
        guard let lastSubmission = lastSubmissionTime else { return 0 }
        let elapsed = Int(Date().timeIntervalSince(lastSubmission))
        return max(0, Int(submissionCooldownDuration) - elapsed)
    }
    private var isSubmissionOnCooldown: Bool {
        remainingSubmissionCooldown > 0
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
        case success(reportType: String, recipeName: String, category: String)
        case failure(String)

        static func == (lhs: SubmissionState, rhs: SubmissionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.submitting, .submitting):
                return true
            case let (.success(lType, lName, lCategory), .success(rType, rName, rCategory)):
                return lType == rType && lName == rName && lCategory == rCategory
            case let (.failure(lError), .failure(rError)):
                return lError == rError
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

    var body: some View {
            NavigationStack {
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 24) {
                            Picker("View Mode", selection: $viewMode) {
                                Text(ViewMode.submitReport.rawValue).tag(ViewMode.submitReport)
                                Text(ViewMode.myReports.rawValue).tag(ViewMode.myReports)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, 16)
                            .accessibilityLabel("View Mode")
                            .accessibilityHint("Select whether to submit a new report or view your reports")

                            if viewMode == .submitReport {
                                SubmitReportSection(
                                    reportType: $reportType,
                                    recipeName: $recipeName,
                                    selectedCategory: $selectedCategory,
                                    recipeErrorName: $recipeErrorName,
                                    recipeErrorCategory: $recipeErrorCategory,
                                    additionalInfo: $additionalInfo,
                                    submissionCooldownMessage: submissionCooldownMessage,
                                    isFormIncomplete: isFormIncomplete,
                                    isSubmissionOnCooldown: isSubmissionOnCooldown,
                                    onSubmit: submitReport
                                )
                            } else {
                                MyReportsSection(
                                    reports: reports.sorted(by: { $0.timestamp > $1.timestamp }),
                                    isLoadingReports: isLoadingReports,
                                    isConnected: dataManager.isConnected,
                                    errorMessage: dataManager.errorMessage,
                                    onDelete: { report in
                                        reportToDelete = report
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                    }
                    .id(accentColorPreference)

                    if showSubmissionPopup {
                        SubmissionPopup(
                            state: submissionState,
                            onDismiss: {
                                showSubmissionPopup = false
                                if case .success = submissionState {
                                    resetForm()
                                    if viewMode == .myReports {
                                        fetchReportStatuses()
                                    }
                                }
                                submissionState = .idle
                            }
                        )
                        .animation(.easeInOut, value: showSubmissionPopup)
                    }

                    if showDeleteConfirmationPopup {
                        DeleteConfirmationPopup(
                            message: deleteConfirmationMessage ?? "",
                            onDismiss: {
                                showDeleteConfirmationPopup = false
                                deleteConfirmationMessage = nil
                            }
                        )
                        .animation(.easeInOut, value: showDeleteConfirmationPopup)
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
                        dataManager.lastReportStatusFetchTime = nil
                        fetchReportStatuses()
                    }
                }
                .onChange(of: reportType) { _, _ in
                    resetForm()
                }
            }
        }

    private func resetForm() {
        recipeName = ""
        selectedCategory = ""
        recipeErrorName = ""
        recipeErrorCategory = ""
        additionalInfo = ""
    }

    private func updateSubmissionCooldownMessage() {
        let remaining = remainingSubmissionCooldown
        submissionCooldownMessage = "Please wait \(remaining) second\(remaining == 1 ? "" : "s") before submitting again."
    }

    private func startSubmissionCooldownTimer() {
        submissionCooldownTimer?.invalidate()
        submissionCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                let remaining = self.remainingSubmissionCooldown
                if remaining > 0 {
                    self.updateSubmissionCooldownMessage()
                } else {
                    self.submissionCooldownMessage = nil
                    timer.invalidate()
                    self.submissionCooldownTimer = nil
                }
            }
        }
    }

    private func submitReport() {
        if isFormIncomplete {
            return
        }

        submissionState = .submitting
        showSubmissionPopup = true

        let reportTypeString = reportType.rawValue
        let recipeNameValue = reportType == .missingRecipe ? recipeName : recipeErrorName
        let categoryValue = reportType == .missingRecipe ? selectedCategory : recipeErrorCategory

        dataManager.submitRecipeReport(
            reportType: reportTypeString,
            recipeName: recipeNameValue,
            category: categoryValue,
            recipeID: nil,
            description: additionalInfo
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.submissionState = .success(
                        reportType: reportTypeString,
                        recipeName: recipeNameValue,
                        category: categoryValue
                    )
                    self.lastSubmissionTime = Date()
                    self.updateSubmissionCooldownMessage()
                    self.startSubmissionCooldownTimer()
                case .failure(let error):
                    self.submissionState = .failure("Failed to submit report: \(error.localizedDescription)")
                }
            }
        }
    }

    private func fetchReportStatuses() {
        guard dataManager.isConnected else {
            isLoadingReports = false
            return
        }

        isLoadingReports = true

        dataManager.fetchRecipeReports { result in
            DispatchQueue.main.async {
                self.isLoadingReports = false
                switch result {
                case .success(let fetchedReports):
                    self.reports = fetchedReports
                case .failure:
                    break
                }
            }
        }
    }

    private func deleteReport(_ report: RecipeReport) {
        withAnimation(.easeInOut(duration: 0.3)) {
            dataManager.deleteRecipeReport(report) { success in
                DispatchQueue.main.async {
                    if success {
                        self.reports.removeAll { $0.id == report.id }
                        self.deleteConfirmationMessage = "Report deleted successfully."
                    } else {
                        self.deleteConfirmationMessage = "Failed to delete report."
                    }
                    self.reportToDelete = nil
                    self.showDeleteConfirmationPopup = true
                }
            }
        }
    }
}

struct SubmitReportSection: View {
    @Binding var reportType: ReportRecipeView.ReportType
    @Binding var recipeName: String
    @Binding var selectedCategory: String
    @Binding var recipeErrorName: String
    @Binding var recipeErrorCategory: String
    @Binding var additionalInfo: String
    let submissionCooldownMessage: String?
    let isFormIncomplete: Bool
    let isSubmissionOnCooldown: Bool
    let onSubmit: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var dataManager: DataManager

    private let categories: [String] = [
        "Beds", "Crafting", "Consumables", "Lighting", "Planks",
        "Smelting", "Storage", "Tools", "Transportation", "Utilities", "Not listed"
    ]
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 500
    private let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ")
    private var fieldHeight: CGFloat {
        horizontalSizeClass == .regular ? 48 : 44
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReportTypeToggle(reportType: $reportType)

            if reportType == .missingRecipe {
                CategoryPicker(selectedCategory: $selectedCategory, categories: categories)
            } else {
                CategoryPicker(selectedCategory: $recipeErrorCategory, categories: categories, isErrorPicker: true)
            }

            CombinedInputFields(
                reportType: reportType,
                recipeName: $recipeName,
                recipeErrorName: $recipeErrorName,
                additionalInfo: $additionalInfo,
                maxRecipeNameLength: maxRecipeNameLength,
                maxAdditionalInfoLength: maxAdditionalInfoLength,
                allowedCharacters: allowedCharacters
            )

            if let message = submissionCooldownMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .accessibilityLabel(message)
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if isFormIncomplete {
                    return
                }
                if isSubmissionOnCooldown {
                    return
                }
                onSubmit()
            }) {
                Text("Submit Report")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        (isFormIncomplete || !dataManager.isConnected || isSubmissionOnCooldown)
                            ? Color.userAccentColor.opacity(0.5)
                            : Color.userAccentColor
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isFormIncomplete || !dataManager.isConnected || isSubmissionOnCooldown)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }
}

struct ReportTypeToggle: View {
    @Binding var reportType: ReportRecipeView.ReportType
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut) {
                    reportType = .missingRecipe
                }
            }) {
                Text("Missing Recipe")
                    .font(.subheadline)
                    .foregroundColor(reportType == .missingRecipe ? .white : Color.userAccentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(reportType == .missingRecipe ? Color.userAccentColor : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Report Missing Recipe")
            .accessibilityHint("Select to report a missing recipe")
            .accessibilityValue(reportType == .missingRecipe ? "Selected" : "Not selected")

            Button(action: {
                withAnimation(.easeInOut) {
                    reportType = .recipeError
                }
            }) {
                Text("Recipe Error")
                    .font(.subheadline)
                    .foregroundColor(reportType == .recipeError ? .white : Color.userAccentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(reportType == .recipeError ? Color.userAccentColor : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Report Recipe Error")
            .accessibilityHint("Select to report an error in a recipe")
            .accessibilityValue(reportType == .recipeError ? "Selected" : "Not selected")
        }
    }
}

struct CategoryPicker: View {
    @Binding var selectedCategory: String
    let categories: [String]
    var isErrorPicker: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var fieldHeight: CGFloat {
        horizontalSizeClass == .regular ? 48 : 44
    }

    var body: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("Select category").tag("")
            ForEach(categories, id: \.self) { cat in
                Text(cat).tag(cat)
            }
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: fieldHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.userAccentColor, lineWidth: 2)
        )
        .pickerStyle(.menu)
        .accessibilityLabel("Category")
        .accessibilityHint(isErrorPicker ? "Select the category of the recipe with an error" : "Select the category of the missing recipe")
    }
}

struct CombinedInputFields: View {
    let reportType: ReportRecipeView.ReportType
    @Binding var recipeName: String
    @Binding var recipeErrorName: String
    @Binding var additionalInfo: String
    let maxRecipeNameLength: Int
    let maxAdditionalInfoLength: Int
    let allowedCharacters: CharacterSet
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var fieldHeight: CGFloat {
        horizontalSizeClass == .regular ? 48 : 44
    }

    var body: some View {
        VStack(spacing: 0) {
            if reportType == .missingRecipe {
                TextField("Recipe name", text: $recipeName)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .onChange(of: recipeName) { _, newValue in
                        let filtered = newValue.filter { allowedCharacters.contains($0.unicodeScalars.first!) }
                        if filtered.count > maxRecipeNameLength {
                            recipeName = String(filtered.prefix(maxRecipeNameLength))
                        } else {
                            recipeName = filtered
                        }
                    }
                    .accessibilityLabel("Recipe name")
                    .accessibilityHint("Enter the name of the missing recipe using only letters, numbers, and spaces")
            } else {
                TextField("Recipe name", text: $recipeErrorName)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .onChange(of: recipeErrorName) { _, newValue in
                        let filtered = newValue.filter { allowedCharacters.contains($0.unicodeScalars.first!) }
                        if filtered.count > maxRecipeNameLength {
                            recipeErrorName = String(filtered.prefix(maxRecipeNameLength))
                        } else {
                            recipeErrorName = filtered
                        }
                    }
                    .accessibilityLabel("Recipe name")
                    .accessibilityHint("Enter the name of the recipe with an error using only letters, numbers, and spaces")
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            ZStack(alignment: .topLeading) {
                Text("Add details...")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(additionalInfo.isEmpty ? 0.7 : 0))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .onChange(of: additionalInfo) { _, _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            // Opacity updated via binding
                        }
                    }
                TextEditorRepresentable(text: $additionalInfo)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight * 2)
                    .onChange(of: additionalInfo) { _, newValue in
                        if newValue.count > maxAdditionalInfoLength {
                            additionalInfo = String(newValue.prefix(maxAdditionalInfoLength))
                        }
                    }
                    .accessibilityLabel("Additional Information")
                    .accessibilityHint("Enter details about the missing recipe or error, up to 500 characters")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 0))

            HStack {
                Spacer()
                Text("\(additionalInfo.count)/\(maxAdditionalInfoLength)")
                    .font(.caption)
                    .foregroundColor(additionalInfo.count > maxAdditionalInfoLength ? .red : .secondary)
                    .padding(.trailing, 16)
                    .padding(.vertical, 4)
                    .accessibilityLabel("Character count: \(additionalInfo.count) out of \(maxAdditionalInfoLength)")
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.userAccentColor, lineWidth: 2)
        )
    }
}

struct MyReportsSection: View {
    let reports: [RecipeReport]
    let isLoadingReports: Bool
    let isConnected: Bool
    let errorMessage: String?
    let onDelete: (RecipeReport) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reports.isEmpty && !isLoadingReports {
                VStack(spacing: 16) {
                    Text(isConnected ? "No Reports Found" : "No Internet Connection")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(isConnected ? "You haven’t submitted any reports yet." : "Please connect to the internet to view your reports.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isConnected ? "No reports found" : "No internet connection")
                .accessibilityValue(isConnected ? "You haven’t submitted any reports yet" : "Please connect to the internet to view reports")
            } else {
                if let errorMessage = errorMessage, isConnected {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .accessibilityLabel("Error: \(errorMessage)")
                }

                if isLoadingReports {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.userAccentColor)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Loading reports")
                } else if isConnected {
                    ForEach(reports, id: \.id) { report in
                        VStack(alignment: .leading, spacing: 8) {
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

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recipe Name")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(report.recipeName)
                                    .font(.body)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(report.category)
                                    .font(.body)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Details")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(report.description)
                                    .font(.body)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Submitted")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(formattedDate(report.timestamp))
                                    .font(.body)
                            }

                            Button(action: {
                                onDelete(report)
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
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    Color.userAccentColor.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1)
                                )
                        )
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Report")
                        .accessibilityValue("\(report.reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error") for \(report.recipeName), Category: \(report.category), Status: \(report.status), Details: \(report.description), Submitted: \(formattedDate(report.timestamp))")
                        .accessibilityHint("Tap the delete button to remove this report")
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }
}

struct SubmissionPopup: View {
    let state: ReportRecipeView.SubmissionState
    let onDismiss: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var accessibilityLabel: String {
        switch state {
        case .submitting:
            return "Submitting report"
        case .success:
            return "Report submitted successfully"
        case .failure:
            return "Report submission failed"
        case .idle:
            return ""
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .success(let reportType, let recipeName, let category):
            return "\(reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error") for \(recipeName) in \(category)"
        case .failure(let errorMessage):
            return errorMessage
        default:
            return ""
        }
    }

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

                case .success(let reportType, let recipeName, let category):
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    Text("Thanks for submitting your report!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(reportType == "Report Missing Recipe" ? "Missing Recipe" : "Recipe Error") for '\(recipeName)' in \(category)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(.isModal)
        }
    }
}

struct DeleteConfirmationPopup: View {
    let message: String
    let onDismiss: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 20) {
                Image(systemName: message.contains("Failed") ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(message.contains("Failed") ? .red : .green)

                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.userAccentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .frame(maxWidth: 300)
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Delete confirmation")
            .accessibilityValue(message)
            .accessibilityAddTraits(.isModal)
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
        textView.isAccessibilityElement = true
        textView.accessibilityLabel = "Additional Information"
        textView.accessibilityHint = "Enter details about the missing recipe or error, up to 500 characters"
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.backgroundColor = UIColor.secondarySystemGroupedBackground
        uiView.font = .preferredFont(forTextStyle: .body)
        uiView.accessibilityValue = text.isEmpty ? "No details entered" : text
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
