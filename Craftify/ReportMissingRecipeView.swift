//
//  ReportMissingRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/03/2025.
//

import SwiftUI
import MessageUI

struct ReportMissingRecipeView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var recipeName: String = ""
    @State private var selectedCategory: String = ""
    @State private var additionalInfo: String = ""
    @State private var isShowingMailView = false
    @State private var isShowingConfirmation = false
    @State private var showValidationErrors = false

    private let categories: [String] = [
        "Beds", "Crafting", "Food", "Lighting", "Planks",
        "Smelting", "Storage", "Tools", "Transportation", "Utilities", "Not listed"
    ]
    private let supportEmail = "hello@davevancauwenberghe.be"
    private let fieldHeight: CGFloat = 44
    private let maxRecipeNameLength = 100
    private let maxAdditionalInfoLength = 1000
    private let primaryColor = Color(hex: "00AA00")

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Category Picker
                        Picker("Category", selection: $selectedCategory) {
                            Text("Select category").tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: fieldHeight)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    showValidationErrors && selectedCategory.isEmpty ? Color.red : primaryColor,
                                    lineWidth: 2
                                )
                        )
                        .pickerStyle(.menu)
                        .accessibilityLabel("Category")
                        .accessibilityHint("Select the category of the missing recipe")

                        // Grouped Input Section (Recipe Name + Additional Info)
                        VStack(spacing: 0) {
                            // Recipe Name
                            TextField("Recipe name", text: $recipeName)
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, minHeight: fieldHeight)
                                .background(Color(.secondarySystemGroupedBackground))
                                .onChange(of: recipeName) {
                                    if recipeName.count > maxRecipeNameLength {
                                        recipeName = String(recipeName.prefix(maxRecipeNameLength))
                                    }
                                }
                                .accessibilityLabel("Recipe name")
                                .accessibilityHint("Enter the name of the missing recipe")

                            Divider()
                                .background(Color(.separator))

                            ZStack(alignment: .topLeading) {
                                Text("Add details...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(additionalInfo.isEmpty ? 0.7 : 0))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                                    .onChange(of: additionalInfo) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            // Opacity updated via binding
                                        }
                                    }
                                TextEditorRepresentable(text: $additionalInfo)
                                    .font(.body)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, minHeight: fieldHeight * 2)
                                    .onChange(of: additionalInfo) {
                                        if additionalInfo.count > maxAdditionalInfoLength {
                                            additionalInfo = String(additionalInfo.prefix(maxAdditionalInfoLength))
                                        }
                                    }
                            }
                            .accessibilityLabel("Additional Information")
                            .accessibilityHint("Enter details about the missing recipe")
                            .accessibilityValue(additionalInfo.isEmpty ? "No details entered" : additionalInfo)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    showValidationErrors && (recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? Color.red : primaryColor,
                                    lineWidth: 2
                                )
                        )

                        Button(action: sendEmail) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send report")
                                    .font(.headline)
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(isFormIncomplete ? Color.accentColor.opacity(0.5) : Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isFormIncomplete)
                        .accessibilityLabel("Send report")
                        .accessibilityHint("Sends the missing recipe report via email")
                    }
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Report missing recipe")
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
            .alert(isPresented: $isShowingConfirmation) {
                Alert(
                    title: Text("Report sent"),
                    message: Text("Thank you for reporting \(recipeName) in \(selectedCategory)!"),
                    dismissButton: .cancel(Text("OK"))
                )
            }
        }
    }

    private var isFormIncomplete: Bool {
        recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedCategory.isEmpty
    }

    private func sendEmail() {
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
