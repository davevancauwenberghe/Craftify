//
//  ReportRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/03/2025.
//

import SwiftUI

struct ReportRecipeView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("accentColorPreference") private var accentColorPreference = "default"

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
    @State private var submissionCooldownTask: Task<Void, Never>?
    @State private var showDeleteConfirmationPopup = false
    @State private var deleteConfirmationMessage: String?

    private let submissionCooldownDuration: TimeInterval = 30

    enum ViewMode: String, CaseIterable {
        case submitReport = "New report"
        case myReports = "My reports"

        var icon: String {
            self == .submitReport ? "square.and.pencil" : "clock.arrow.circlepath"
        }
    }

    enum ReportType: String {
        case missingRecipe = "Report Missing Recipe"
        case recipeError = "Report Recipe Error"

        var title: String { self == .missingRecipe ? "Missing recipe" : "Recipe error" }
        var subtitle: String {
            self == .missingRecipe
                ? "Tell us what you would like to craft."
                : "Help us fix instructions that are not quite right."
        }
        var icon: String { self == .missingRecipe ? "plus.magnifyingglass" : "exclamationmark.triangle.fill" }
    }

    enum SubmissionState: Equatable {
        case idle
        case submitting
        case success(reportType: String, recipeName: String, category: String)
        case failure(String)
    }

    private var isFormIncomplete: Bool {
        let name = reportType == .missingRecipe ? recipeName : recipeErrorName
        let category = reportType == .missingRecipe ? selectedCategory : recipeErrorCategory
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || category.isEmpty
            || additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var remainingSubmissionCooldown: Int {
        guard let lastSubmissionTime else { return 0 }
        return max(0, Int(submissionCooldownDuration) - Int(Date().timeIntervalSince(lastSubmissionTime)))
    }

    private var isSubmissionOnCooldown: Bool { remainingSubmissionCooldown > 0 }
    private var contentWidth: CGFloat? { horizontalSizeClass == .regular ? 720 : nil }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {
                    introHeader
                    modeSelector

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
                            reports: reports.sorted { $0.timestamp > $1.timestamp },
                            isLoadingReports: isLoadingReports,
                            isConnected: dataManager.isConnected,
                            errorMessage: dataManager.errorMessage,
                            onRefresh: fetchReportStatuses,
                            onDelete: {
                                reportToDelete = $0
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .id(accentColorPreference)

            if showSubmissionPopup {
                SubmissionPopup(state: submissionState, onDismiss: dismissSubmissionPopup)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
            }

            if showDeleteConfirmationPopup {
                DeleteConfirmationPopup(message: deleteConfirmationMessage ?? "") {
                    showDeleteConfirmationPopup = false
                    deleteConfirmationMessage = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(2)
            }
        }
        .navigationTitle("Report a Recipe")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .alert("Delete report?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let reportToDelete { deleteReport(reportToDelete) }
            }
            Button("Keep Report", role: .cancel) { reportToDelete = nil }
        } message: {
            Text("This report and its progress will be permanently removed.")
        }
        .onAppear {
            if viewMode == .myReports { fetchReportStatuses() }
            if isSubmissionOnCooldown {
                updateSubmissionCooldownMessage()
                startSubmissionCooldownTask()
            }
        }
        .onChange(of: viewMode) { _, newMode in
            HapticFeedback.selection()
            if newMode == .myReports {
                dataManager.lastReportStatusFetchTime = nil
                fetchReportStatuses()
            }
        }
        .onChange(of: reportType) { _, _ in resetForm() }
        .onDisappear {
            submissionCooldownTask?.cancel()
            submissionCooldownTask = nil
        }
    }

    private var introHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.userAccentColor.gradient)
                Image(systemName: "hammer.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            .shadow(color: Color.userAccentColor.opacity(0.22), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Help improve Craftify")
                    .font(.title3.bold())
                Text("Send feedback and follow every update in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.snappy) { viewMode = mode }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewMode == mode ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(viewMode == mode ? Color.userAccentColor : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewMode == mode ? .isSelected : [])
            }
        }
        .padding(5)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        submissionCooldownMessage = remaining > 0
            ? "You can send another report in \(remaining) second\(remaining == 1 ? "" : "s")."
            : nil
    }

    private func startSubmissionCooldownTask() {
        submissionCooldownTask?.cancel()
        submissionCooldownTask = Task { @MainActor in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                updateSubmissionCooldownMessage()
                if remainingSubmissionCooldown == 0 {
                    submissionCooldownTask = nil
                    return
                }
            }
        }
    }

    private func submitReport() {
        guard !isFormIncomplete, !isSubmissionOnCooldown, dataManager.isConnected else { return }
        HapticFeedback.impact(.light)
        submissionState = .submitting
        withAnimation(.easeInOut(duration: 0.2)) { showSubmissionPopup = true }

        let type = reportType.rawValue
        let name = reportType == .missingRecipe ? recipeName : recipeErrorName
        let category = reportType == .missingRecipe ? selectedCategory : recipeErrorCategory
        dataManager.submitRecipeReport(
            reportType: type,
            recipeName: name,
            category: category,
            recipeID: nil,
            description: additionalInfo
        ) { result in
            switch result {
            case .success:
                HapticFeedback.notification(.success)
                submissionState = .success(reportType: type, recipeName: name, category: category)
                lastSubmissionTime = Date()
                updateSubmissionCooldownMessage()
                startSubmissionCooldownTask()
            case .failure(let error):
                HapticFeedback.notification(.error)
                submissionState = .failure("Failed to submit report: \(error.localizedDescription)")
            }
        }
    }

    private func dismissSubmissionPopup() {
        withAnimation(.easeInOut(duration: 0.2)) { showSubmissionPopup = false }
        if case .success = submissionState { resetForm() }
        submissionState = .idle
    }

    private func fetchReportStatuses() {
        guard dataManager.isConnected else {
            isLoadingReports = false
            return
        }
        isLoadingReports = true
        dataManager.fetchRecipeReports { result in
            isLoadingReports = false
            if case .success(let fetchedReports) = result { reports = fetchedReports }
        }
    }

    private func deleteReport(_ report: RecipeReport) {
        dataManager.deleteRecipeReport(report) { success in
            if success {
                withAnimation { reports.removeAll { $0.id == report.id } }
                deleteConfirmationMessage = "Report deleted."
                HapticFeedback.notification(.success)
            } else {
                deleteConfirmationMessage = "We couldn’t delete this report. Please try again."
                HapticFeedback.notification(.error)
            }
            reportToDelete = nil
            withAnimation { showDeleteConfirmationPopup = true }
        }
    }
}

private struct SubmitReportSection: View {
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

    @EnvironmentObject private var dataManager: DataManager
    @FocusState private var focusedField: Field?

    private enum Field { case name, details }
    private let categories = [
        "Beds", "Crafting", "Consumables", "Lighting", "Planks", "Smelting",
        "Storage", "Tools", "Transportation", "Utilities", "Not listed"
    ]
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 500
    private let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ")

    private var activeName: Binding<String> {
        reportType == .missingRecipe ? $recipeName : $recipeErrorName
    }
    private var activeCategory: Binding<String> {
        reportType == .missingRecipe ? $selectedCategory : $recipeErrorCategory
    }
    private var completedSteps: Int {
        var result = 1
        if !activeName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result += 1 }
        if !activeCategory.wrappedValue.isEmpty { result += 1 }
        if !additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result += 1 }
        return result
    }

    var body: some View {
        VStack(spacing: 16) {
            sectionHeader
            reportTypeCards
            detailsCard

            if !dataManager.isConnected {
                InlineNotice(icon: "wifi.slash", message: "Connect to the internet to send your report.", tint: .orange)
            } else if let submissionCooldownMessage {
                InlineNotice(icon: "timer", message: submissionCooldownMessage, tint: .secondary)
            }

            Button {
                focusedField = nil
                onSubmit()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                    Text("Send report").fontWeight(.bold)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 54)
                .background(Color.userAccentColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(isFormIncomplete || !dataManager.isConnected || isSubmissionOnCooldown ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isFormIncomplete || !dataManager.isConnected || isSubmissionOnCooldown)
            .accessibilityHint(isFormIncomplete ? "Complete all fields before sending" : "Submits this recipe report")
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Create a report").font(.title2.bold())
                Text("A few quick details help us investigate faster.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(completedSteps)/4")
                .font(.caption.bold())
                .foregroundStyle(Color.userAccentColor)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.userAccentColor.opacity(0.12), in: Capsule())
        }
    }

    private var reportTypeCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT HAPPENED?").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                typeButton(.missingRecipe)
                typeButton(.recipeError)
            }
        }
    }

    private func typeButton(_ type: ReportRecipeView.ReportType) -> some View {
        Button {
            guard reportType != type else { return }
            withAnimation(.snappy) { reportType = type }
            HapticFeedback.selection()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: type.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(reportType == type ? Color.white : Color.userAccentColor)
                Text(type.title).font(.subheadline.bold())
                    .foregroundStyle(reportType == type ? Color.white : Color.primary)
                Text(type == .missingRecipe ? "Request a new guide" : "Flag incorrect steps")
                    .font(.caption)
                    .foregroundStyle(reportType == type ? Color.white.opacity(0.85) : Color.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(14)
            .background(reportType == type ? Color.userAccentColor : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(reportType == type ? Color.clear : Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .accessibilityValue(reportType == type ? "Selected" : "Not selected")
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(reportType.subtitle, systemImage: reportType.icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.userAccentColor)

            LabeledContentField(title: "Recipe name", icon: "cube.fill") {
                TextField("e.g. Copper Torch", text: activeName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .details }
                    .onChange(of: activeName.wrappedValue) { _, newValue in
                        let filtered = newValue.filter { character in
                            character.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
                        }
                        activeName.wrappedValue = String(filtered.prefix(maxRecipeNameLength))
                    }
            }

            Divider()

            LabeledContentField(title: "Category", icon: "square.grid.2x2.fill") {
                Picker("Select a category", selection: activeCategory) {
                    Text("Select a category").tag("")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(activeCategory.wrappedValue.isEmpty ? .secondary : Color.userAccentColor)
            }

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("Details", systemImage: "text.alignleft").font(.subheadline.bold())
                    Spacer()
                    Text("\(additionalInfo.count)/\(maxAdditionalInfoLength)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                ZStack(alignment: .topLeading) {
                    if additionalInfo.isEmpty {
                        Text(reportType == .missingRecipe
                             ? "Where did you expect to find this recipe?"
                             : "What looks wrong, and what should it show instead?")
                            .font(.body).foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $additionalInfo)
                        .focused($focusedField, equals: .details)
                        .frame(minHeight: 105)
                        .scrollContentBackground(.hidden)
                        .onChange(of: additionalInfo) { _, value in
                            if value.count > maxAdditionalInfoLength {
                                additionalInfo = String(value.prefix(maxAdditionalInfoLength))
                            }
                        }
                }
                .padding(8)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LabeledContentField<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.bold())
            content
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct InlineNotice: View {
    let icon: String
    let message: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

private struct MyReportsSection: View {
    let reports: [RecipeReport]
    let isLoadingReports: Bool
    let isConnected: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onDelete: (RecipeReport) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("My reports").font(.title2.bold())
                    Text("Track feedback from submission to resolution.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    HapticFeedback.impact(.light)
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.bold())
                        .frame(width: 38, height: 38)
                        .background(Color.userAccentColor.opacity(0.12), in: Circle())
                }
                .disabled(isLoadingReports || !isConnected)
                .accessibilityLabel("Refresh reports")
            }

            if isLoadingReports {
                loadingCard
            } else if !isConnected {
                EmptyReportState(icon: "wifi.slash", title: "You’re offline", message: "Reconnect to check the latest progress on your reports.")
            } else if reports.isEmpty {
                EmptyReportState(icon: "tray", title: "No reports yet", message: "When you send feedback, its progress will appear here.")
            } else {
                if let errorMessage {
                    InlineNotice(icon: "exclamationmark.circle", message: errorMessage, tint: .red)
                }
                LazyVStack(spacing: 12) {
                    ForEach(reports, id: \.id) { report in
                        ReportCard(report: report) { onDelete(report) }
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Color.userAccentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text("Checking for updates").font(.headline)
                Text("This should only take a moment.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyReportState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.userAccentColor)
                .frame(width: 64, height: 64)
                .background(Color.userAccentColor.opacity(0.12), in: Circle())
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28).padding(.vertical, 34)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ReportCard: View {
    let report: RecipeReport
    let onDelete: () -> Void
    @State private var isExpanded = false

    private var isPending: Bool { report.status.localizedCaseInsensitiveContains("pending") }
    private var isResolved: Bool {
        report.status.localizedCaseInsensitiveContains("resolved")
            || report.status.localizedCaseInsensitiveContains("complete")
            || report.status.localizedCaseInsensitiveContains("fixed")
    }
    private var statusColor: Color { isPending ? .orange : (isResolved ? .green : Color.userAccentColor) }
    private var statusIcon: String { isPending ? "clock.fill" : (isResolved ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath") }
    private var isMissingRecipe: Bool { report.reportType == "Report Missing Recipe" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
                HapticFeedback.selection()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isMissingRecipe ? "plus.magnifyingglass" : "exclamationmark.triangle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.userAccentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.userAccentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.recipeName).font(.headline).foregroundStyle(.primary).lineLimit(2)
                        Text("\(isMissingRecipe ? "Missing recipe" : "Recipe error") • \(report.category)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack {
                Label(report.status, systemImage: statusIcon)
                    .font(.caption.bold()).foregroundStyle(statusColor)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(statusColor.opacity(0.12), in: Capsule())
                Spacer()
                Text(report.timestamp, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption).foregroundStyle(.secondary)
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR DETAILS").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(report.description).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete report", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(statusColor).frame(width: 4).padding(.vertical, 18)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SubmissionPopup: View {
    let state: ReportRecipeView.SubmissionState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
                .onTapGesture { if state != .submitting { onDismiss() } }
            VStack(spacing: 18) {
                switch state {
                case .submitting:
                    ProgressView().controlSize(.large).tint(Color.userAccentColor)
                    Text("Sending your report…").font(.headline)
                    Text("Hang tight while we securely save your feedback.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                case .success(_, let recipeName, _):
                    popupIcon("checkmark", color: .green)
                    Text("Report sent!").font(.title3.bold())
                    Text("Thanks for helping improve \(recipeName). You can follow its progress in My reports.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                case .failure(let message):
                    popupIcon("exclamationmark", color: .red)
                    Text("Couldn’t send report").font(.title3.bold())
                    Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                case .idle:
                    EmptyView()
                }
                if state != .submitting {
                    Button("Done", action: onDismiss)
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.userAccentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(24)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func popupIcon(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 25, weight: .bold)).foregroundStyle(.white)
            .frame(width: 58, height: 58).background(color, in: Circle())
    }
}

private struct DeleteConfirmationPopup: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 18) {
                Image(systemName: message.contains("couldn’t") ? "exclamationmark" : "checkmark")
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(message.contains("couldn’t") ? Color.red : Color.green, in: Circle())
                Text(message).font(.headline).multilineTextAlignment(.center)
                Button("Done", action: onDismiss)
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.userAccentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(24).frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(24).accessibilityAddTraits(.isModal)
        }
    }
}
