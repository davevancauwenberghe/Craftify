//
//  ReportMissingRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/03/2025.
//

import SwiftUI
import MessageUI

struct ReportMissingRecipeView: View {
    @State private var recipeName: String = ""
    @State private var selectedCategory: String = ""
    @State private var additionalInfo: String = ""
    @State private var isShowingMailView = false
    @State private var isShowingConfirmation = false
    @State private var showValidationErrors = false

    private let categories: [String] = [
        "Beds", "Crafting", "Food", "Lighting", "Planks",
        "Smelting", "Storage", "Tools", "Transportation", "Utilities"
    ]
    private let supportEmail = "hello@davevancauwenberghe.be"
    private let fieldHeight: CGFloat = 44
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 1000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Category Picker
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(showValidationErrors && selectedCategory.isEmpty ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .pickerStyle(.menu)
                    .accessibilityLabel("Category")
                    .accessibilityHint("Select the category of the missing recipe")

                    // Grouped Input Section (Recipe Name + Additional Info)
                    VStack(spacing: 0) {
                        // Recipe Name
                        TextField("Recipe Name", text: $recipeName)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: fieldHeight)
                            .onChange(of: recipeName) { oldValue, newValue in
                                if newValue.count > maxRecipeNameLength {
                                    recipeName = String(newValue.prefix(maxRecipeNameLength))
                                }
                            }
                            .accessibilityLabel("Recipe Name")
                            .accessibilityHint("Enter the name of the missing recipe")

                        Divider()
                            .background(Color(UIColor.separator))

                        ZStack(alignment: .topLeading) {
                            Text("Add details...")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .opacity(additionalInfo.isEmpty ? 0.7 : 0)
                                .animation(.easeInOut(duration: 0.2), value: additionalInfo.isEmpty)
                            TextEditor(text: $additionalInfo)
                                .font(.body)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, minHeight: fieldHeight * 2)
                                .onChange(of: additionalInfo) { oldValue, newValue in
                                    if newValue.count > maxAdditionalInfoLength {
                                        additionalInfo = String(newValue.prefix(maxAdditionalInfoLength))
                                    }
                                }
                        }
                        .accessibilityLabel("Additional Information")
                        .accessibilityHint("Enter details about the missing recipe")
                        .accessibilityValue(additionalInfo.isEmpty ? "No details entered" : additionalInfo)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(showValidationErrors && (recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .padding(.horizontal, 2)

                    Button(action: sendEmail) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Report")
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormIncomplete ? Color.accentColor.opacity(0.5) : Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isFormIncomplete)
                    .accessibilityLabel("Send Report")
                    .accessibilityHint("Sends the missing recipe report via email")
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Report Missing Recipe")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingMailView) {
                MailView(
                    isShowing: $isShowingMailView,
                    isShowingConfirmation: $isShowingConfirmation,
                    subject: "Missing Recipe Report",
                    body: emailBody(),
                    supportEmail: supportEmail
                )
            }
            .alert("Report Sent", isPresented: $isShowingConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for reporting \(recipeName) in \(selectedCategory)!")
            }
        }
    }

    private var isFormIncomplete: Bool {
        recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedCategory.isEmpty
    }

    private func sendEmail() {
        // Show validation errors if form is incomplete
        if isFormIncomplete {
            showValidationErrors = true
            return
        }

        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            let subject = "Missing Recipe Report".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let body = emailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)&body=\(body)") {
                UIApplication.shared.open(url) { success in
                    if success {
                        isShowingConfirmation = true

                    } else {
                        print("Failed to open mail client")

                    }
                }
            } else {
                print("Invalid mailto URL")
            }
        }
    }

    private func emailBody() -> String {
        """
        Category: \(selectedCategory)
        Recipe Name: \(recipeName)
        
        Additional Information:
        \(additionalInfo)
        """
    }
}

struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    @Binding var isShowingConfirmation: Bool
    var subject: String
    var body: String
    var supportEmail: String

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView

        init(parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            parent.isShowing = false
            if result == .sent {
                parent.isShowingConfirmation = true
                // Optional: Track successful email send
                // Analytics.logEvent("report_missing_recipe_sent", parameters: nil)
            } else if let error = error {
                print("Mail error: \(error.localizedDescription)")
                // Optional: Show error alert
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setToRecipients([supportEmail])
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
