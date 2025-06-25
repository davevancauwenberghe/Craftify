//
//  ReportRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/03/2025.
//

import SwiftUI
import UIKit
import UserNotifications
import CloudKit

// MARK: – Enums for ReportRecipeView

/// Which “tab” of the view we’re on
enum ViewMode: String {
    case submitReport  = "Submit Report"
    case myReports     = "My Reports"
}

/// Which kind of report the user is filling out
enum ReportType: String {
    case missingRecipe = "Report Missing Recipe"
    case recipeError   = "Report Recipe Error"
}

/// Tracks the submission flow
enum SubmissionState: Equatable {
    case idle
    case submitting
    case success(reportType: String, recipeName: String, category: String)
    case failure(String)

    static func == (lhs: SubmissionState, rhs: SubmissionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.submitting, .submitting): return true
        case (.success(let a1, let b1, let c1), .success(let a2, let b2, let c2)):
            return a1 == a2 && b1 == b2 && c1 == c2
        case (.failure(let e1), .failure(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

struct ReportRecipeView: View {
    // MARK: – Environment & State

    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @Binding var navigateToMyReports: Bool

    // Use your new NotificationManager
    private let notificationManager = NotificationManager()

    @State private var viewMode: ViewMode = .submitReport
    @State private var reportType: ReportType = .missingRecipe
    @State private var recipeName = ""
    @State private var selectedCategory = ""
    @State private var recipeErrorName = ""
    @State private var recipeErrorCategory = ""
    @State private var additionalInfo = ""
    @State private var reports: [RecipeReport] = []
    @State private var isLoadingReports = false
    @State private var reportToDelete: RecipeReport?
    @State private var showDeleteConfirmation = false
    @State private var submissionState: SubmissionState = .idle
    @State private var showSubmissionPopup = false
    @State private var lastSubmissionTime: Date?
    @State private var submissionCooldownMessage: String?
    @State private var submissionCooldownTimer: Timer?
    @State private var showDeleteConfirmationPopup = false
    @State private var deleteConfirmationMessage: String?
    @State private var showNotificationPermissionPrompt = false

    // MARK: – Constants

    private let categories = [
        "Beds","Crafting","Consumables","Lighting","Planks",
        "Smelting","Storage","Tools","Transportation","Utilities","Not listed"
    ]
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 500
    private let submissionCooldownDuration: TimeInterval = 30
    private let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces)

    // MARK: – Computed Properties

    private var fieldHeight: CGFloat {
        horizontalSizeClass == .regular ? 48 : 44
    }

    private var remainingSubmissionCooldown: Int {
        guard let last = lastSubmissionTime else { return 0 }
        let elapsed = Int(Date().timeIntervalSince(last))
        return max(0, Int(submissionCooldownDuration) - elapsed)
    }

    private var isSubmissionOnCooldown: Bool { remainingSubmissionCooldown > 0 }

    private var isFormIncomplete: Bool {
        let name = reportType == .missingRecipe ? recipeName : recipeErrorName
        let category = reportType == .missingRecipe ? selectedCategory : recipeErrorCategory
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || category.isEmpty
            || additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        viewModePicker
                        if viewMode == .submitReport {
                            submitReportSection
                        } else {
                            myReportsSection
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .id(accentColorPreference)
                }
                popupOverlays
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                if viewMode == .myReports {
                    fetchReportStatuses()
                }
            }
            .onChange(of: viewMode) { old, new in
                if new == .myReports {
                    dataManager.lastReportStatusFetchTime = nil
                    fetchReportStatuses()
                }
            }
            .onChange(of: reportType) { _ in
                resetForm()
            }
            .onChange(of: notificationsEnabled) { newValue in
                handleNotificationToggle(newValue)
            }
            .onChange(of: navigateToMyReports) { _, new in
                if new {
                    viewMode = .myReports
                    fetchReportStatuses()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMyReports)) { _ in
                viewMode = .myReports
                fetchReportStatuses()
            }
            .alert("Delete Report", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let rpt = reportToDelete { deleteReport(rpt) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this report? This action cannot be undone.")
            }
        }
    }

    // MARK: – View Builders

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            Text(ViewMode.submitReport.rawValue).tag(ViewMode.submitReport)
            Text(ViewMode.myReports.rawValue).tag(ViewMode.myReports)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    private var submitReportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportTypeToggle
            if reportType == .missingRecipe {
                categoryPicker
            } else {
                recipeErrorCategoryPicker
            }
            combinedInputFields
            if let msg = submissionCooldownMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
            }
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if isFormIncomplete {
                    return
                } else if isSubmissionOnCooldown {
                    updateSubmissionCooldownMessage()
                    startSubmissionCooldownTimer()
                } else {
                    submitReport()
                }
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
        }
        .padding(.horizontal, 16)
    }

    private var myReportsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if reports.isEmpty && !isLoadingReports {
                noReportsView
            } else {
                if let err = dataManager.errorMessage, dataManager.isConnected {
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
                if isLoadingReports {
                    ProgressView().tint(Color.userAccentColor)
                } else if dataManager.isConnected {
                    ForEach(reports.sorted(by: { $0.timestamp > $1.timestamp })) { report in
                        reportCard(report)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var noReportsView: some View {
        VStack(spacing: 16) {
            Text(dataManager.isConnected ? "No Reports Found" : "No Internet Connection")
                .font(.title2).bold()
            Text(dataManager.isConnected
                 ? "You haven’t submitted any reports yet."
                 : "Please connect to view your reports.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func reportCard(_ report: RecipeReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.reportType.contains("Missing") ? "Missing Recipe" : "Recipe Error")
                    .font(.headline)
                    .foregroundColor(Color.userAccentColor)
                Spacer()
                Text(report.status)
                    .font(.subheadline)
                    .foregroundColor(report.status == "Pending" ? .orange : .green)
                    .padding(6)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            detailRow("Recipe Name", report.recipeName)
            detailRow("Category", report.category)
            detailRow("Details", report.description)
            detailRow("Submitted", formattedDate(report.timestamp))
            Button("Delete Report") {
                reportToDelete = report
                showDeleteConfirmation = true
            }
            .font(.subheadline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.userAccentColor.opacity(0.3), lineWidth: 1))
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Text(value).font(.body)
        }
    }

    private var popupOverlays: some View {
        Group {
            if showSubmissionPopup {
                SubmissionPopup(state: submissionState) {
                    showSubmissionPopup = false
                    if case .success = submissionState {
                        resetForm()
                        if viewMode == .myReports { fetchReportStatuses() }
                        if !notificationsEnabled {
                            showNotificationPermissionPrompt = true
                        }
                    }
                    submissionState = .idle
                }
            }
            if showDeleteConfirmationPopup {
                DeleteConfirmationPopup(message: deleteConfirmationMessage ?? "") {
                    showDeleteConfirmationPopup = false
                    deleteConfirmationMessage = nil
                }
            }
            if showNotificationPermissionPrompt {
                NotificationPermissionPopup(
                    onAllow: {
                        requestNotificationPermission()
                        showNotificationPermissionPrompt = false
                    },
                    onDeny: {
                        showNotificationPermissionPrompt = false
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var reportTypeToggle: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { reportType = .missingRecipe }
            } label: {
                Text("Missing Recipe")
                    .font(.subheadline)
                    .foregroundColor(reportType == .missingRecipe ? .white : Color.userAccentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(reportType == .missingRecipe ? Color.userAccentColor : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                withAnimation { reportType = .recipeError }
            } label: {
                Text("Recipe Error")
                    .font(.subheadline)
                    .foregroundColor(reportType == .recipeError ? .white : Color.userAccentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(reportType == .recipeError ? Color.userAccentColor : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("Select category").tag("")
            ForEach(categories, id: \.self) { cat in
                Text(cat).tag(cat)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: fieldHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.userAccentColor, lineWidth: 2))
        .pickerStyle(.menu)
    }

    private var recipeErrorCategoryPicker: some View {
        Picker("Category", selection: $recipeErrorCategory) {
            Text("Select category").tag("")
            ForEach(categories, id: \.self) { cat in
                Text(cat).tag(cat)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: fieldHeight)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.userAccentColor, lineWidth: 2))
        .pickerStyle(.menu)
    }

    private var combinedInputFields: some View {
        VStack(spacing: 0) {
            if reportType == .missingRecipe {
                TextField("Recipe name", text: $recipeName)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .onChange(of: recipeName) { _, new in
                        let filtered = new.filter { allowedCharacters.contains($0.unicodeScalars.first!) }
                        recipeName = String(filtered.prefix(maxRecipeNameLength))
                    }
            } else {
                TextField("Recipe name", text: $recipeErrorName)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .onChange(of: recipeErrorName) { _, new in
                        let filtered = new.filter { allowedCharacters.contains($0.unicodeScalars.first!) }
                        recipeErrorName = String(filtered.prefix(maxRecipeNameLength))
                    }
            }
            Divider().background(Color.gray.opacity(0.3))
            ZStack(alignment: .topLeading) {
                if additionalInfo.isEmpty {
                    Text("Add details...")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                TextEditorRepresentable(text: $additionalInfo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(minHeight: fieldHeight * 2)
                    .onChange(of: additionalInfo) { _, new in
                        if new.count > maxAdditionalInfoLength {
                            additionalInfo = String(new.prefix(maxAdditionalInfoLength))
                        }
                    }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Spacer()
                Text("\(additionalInfo.count)/\(maxAdditionalInfoLength)")
                    .font(.caption)
                    .foregroundColor(additionalInfo.count > maxAdditionalInfoLength ? .red : .secondary)
                    .padding(.trailing, 16)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Helper Methods

    private func handleNotificationToggle(_ enabled: Bool) {
        #if os(iOS)
        if enabled {
            notificationManager.requestUserPermissions { granted in
                guard granted else {
                    DispatchQueue.main.async { notificationsEnabled = false }
                    return
                }
                notificationManager.registerForRemoteNotifications()
                CKContainer(identifier: "iCloud.craftifydb")
                    .fetchUserRecordID { recordID, error in
                        DispatchQueue.main.async {
                            guard let recordID = recordID, error == nil else {
                                notificationsEnabled = false
                                return
                            }
                            notificationManager.createReportStatusSubscription(for: recordID) { result in
                                if case .failure = result {
                                    notificationsEnabled = false
                                }
                            }
                        }
                    }
            }
        } else {
            CKContainer(identifier: "iCloud.craftifydb")
                .fetchUserRecordID { recordID, error in
                    DispatchQueue.main.async {
                        guard let recordID = recordID, error == nil else { return }
                        notificationManager.deleteReportStatusSubscription(for: recordID) { _ in }
                    }
                }
        }
        #endif
    }

    private func fetchReportStatuses() {
        guard dataManager.isConnected else {
            isLoadingReports = false
            return
        }
        isLoadingReports = true
        dataManager.fetchRecipeReports { result in
            DispatchQueue.main.async {
                isLoadingReports = false
                if case .success(let fetched) = result {
                    reports = fetched
                }
            }
        }
    }

    private func submitReport() {
        submissionState = .submitting
        showSubmissionPopup = true
        let rt = reportType.rawValue
        let name = reportType == .missingRecipe ? recipeName : recipeErrorName
        let cat  = reportType == .missingRecipe ? selectedCategory : recipeErrorCategory

        dataManager.submitRecipeReport(
            reportType: rt,
            recipeName: name,
            category: cat,
            recipeID: nil,
            description: additionalInfo
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    submissionState = .success(reportType: rt, recipeName: name, category: cat)
                    lastSubmissionTime = Date()
                    updateSubmissionCooldownMessage()
                    startSubmissionCooldownTimer()
                case .failure(let error):
                    submissionState = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func deleteReport(_ report: RecipeReport) {
        withAnimation {
            dataManager.deleteRecipeReport(report) { success in
                DispatchQueue.main.async {
                    if success {
                        reports.removeAll { $0.id == report.id }
                        deleteConfirmationMessage = "Report deleted successfully."
                    } else {
                        deleteConfirmationMessage = "Failed to delete report."
                    }
                    showDeleteConfirmationPopup = true
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    notificationsEnabled = granted
                    if granted {
                        handleNotificationToggle(true)
                    }
                }
            }
    }

    private func updateSubmissionCooldownMessage() {
        let rem = remainingSubmissionCooldown
        submissionCooldownMessage = "Please wait \(rem) second\(rem == 1 ? "" : "s") before submitting again."
    }

    private func startSubmissionCooldownTimer() {
        submissionCooldownTimer?.invalidate()
        submissionCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                if remainingSubmissionCooldown > 0 {
                    updateSubmissionCooldownMessage()
                } else {
                    submissionCooldownMessage = nil
                    timer.invalidate()
                }
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

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: – Popups & Helpers

struct NotificationPermissionPopup: View {
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDeny() }
            VStack(spacing: 20) {
                Image(systemName: "bell.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color.userAccentColor)
                Text("Enable Notifications")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Receive updates when your report status changes?")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Button("Deny") { onDeny() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("Allow") { onAllow() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.userAccentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .frame(maxWidth: 300)
        }
    }
}

struct SubmissionPopup: View {
    let state: SubmissionState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture {
                    if state != .submitting {
                        onDismiss()
                    }
                }
            VStack(spacing: 20) {
                switch state {
                case .submitting:
                    ProgressView().scaleEffect(1.5)
                    Text("Sending report...")
                case .success(let rt, let name, let cat):
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    Text("Reported \(name) (\(cat))!")
                        .multilineTextAlignment(.center)
                case .failure(let err):
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.red)
                    Text("Failed to submit")
                    Text(err).font(.subheadline).foregroundColor(.secondary)
                case .idle:
                    EmptyView()
                }
                if state != .submitting {
                    Button("OK") { onDismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.userAccentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .frame(maxWidth: 300)
        }
    }
}

struct DeleteConfirmationPopup: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 20) {
                Image(systemName: message.contains("Failed") ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(message.contains("Failed") ? .red : .green)
                Text(message).multilineTextAlignment(.center)
                Button("OK") { onDismiss() }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.userAccentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .frame(maxWidth: 300)
        }
    }
}

struct TextEditorRepresentable: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .secondarySystemGroupedBackground
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextEditorRepresentable
        init(_ parent: TextEditorRepresentable) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
    }
}
