//
//  ReportMissingRecipeView.swift
//  Craftify
//
//  Created by Dave Van Cauwenberghe on 07/03/2025.
//

import SwiftUI
import MessageUI
import CloudKit

struct ReportMissingRecipeView: View {
    @State private var recipeName: String = ""
    @State private var selectedCategory: String = ""
    @State private var categories: [String] = []
    @State private var additionalInfo: String = ""
    @State private var isShowingMailView = false
    @State private var isShowingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack {
                // Main scrolling content aligned to top
                ScrollView {
                    VStack(spacing: 24) {
                        // Category picker, same height as text fields
                        Picker("Category", selection: $selectedCategory) {
                            Text("Select Category").tag("")
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)

                        // Recipe Name field
                        TextField("Recipe Name", text: $recipeName)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)

                        // Add Details field with placeholder
                        ZStack(alignment: .topLeading) {
                            if additionalInfo.isEmpty {
                                Text("Add details...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(12)
                            }
                            TextEditor(text: $additionalInfo)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 150)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)

                        // Send button
                        Button(action: sendEmail) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send Report")
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormIncomplete ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isFormIncomplete)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Report Missing Recipe")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingMailView) {
                // Mail compose view
                MailView(isShowing: $isShowingMailView,
                         subject: "Missing Recipe Report",
                         body: emailBody())
            }
            .alert("Report Sent", isPresented: $isShowingConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for your submission!")
            }
            .onAppear(perform: fetchCategories)
        }
    }

    private var isFormIncomplete: Bool {
        recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedCategory.isEmpty
    }

    private func fetchCategories() {
        let query = CKQuery(recordType: "Recipe", predicate: NSPredicate(value: true))
        let op = CKQueryOperation(query: query)
        op.desiredKeys = ["category"]
        op.resultsLimit = CKQueryOperation.maximumResults
        var fetched = Set<String>()
        op.recordMatchedBlock = { _, result in
            if case .success(let rec) = result,
               let cat = rec["category"] as? String {
                fetched.insert(cat)
            }
        }
        op.queryResultBlock = { res in
            if case .success = res {
                DispatchQueue.main.async {
                    categories = Array(fetched).sorted()
                }
            }
        }
        CKContainer.default().publicCloudDatabase.add(op)
    }

    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            // fallback to mailto URL
            let subject = "Missing Recipe Report"
            let body = emailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:hello@davevancauwenberghe.be?subject=\(subject)&body=\(body)") {
                UIApplication.shared.open(url)
            }
            isShowingConfirmation = true
        }
    }

    private func emailBody() -> String {
        "Category: \(selectedCategory)\nRecipe Name: \(recipeName)\n\nAdditional Information:\n\(additionalInfo)"
    }
}

// MARK: - MailView

struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    var subject: String
    var body: String

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
                // show confirmation
                DispatchQueue.main.async {
                    // parent view's isShowingConfirmation bound in ReportMissingRecipeView
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setToRecipients(["hello@davevancauwenberghe.be"])
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: Context) {}
}
