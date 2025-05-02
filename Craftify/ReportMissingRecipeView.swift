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
    @State private var additionalInfo: String = "Add details..."
    @State private var isShowingMailView = false
    @State private var isShowingConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Default system background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Input fields header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Missing Recipe Details")
                                .font(.subheadline)
                                .fontWeight(.none)
                            Divider()
                        }
                        .padding(.horizontal)

                        // Input fields
                        VStack(spacing: 16) {
                            TextField("Recipe Name", text: $recipeName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            ZStack(alignment: .topLeading) {
                                if additionalInfo.isEmpty || additionalInfo == "Add details..." {
                                    Text("Add details...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.horizontal, 4)
                                }
                                TextEditor(text: $additionalInfo)
                                    .frame(height: 150)
                                    .padding(4)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        if additionalInfo == "Add details..." {
                                            additionalInfo = ""
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)

                        // Send button
                        Button(action: sendEmail) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send Report")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(recipeName.isEmpty ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(recipeName.isEmpty)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Report Missing Recipe")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingMailView) {
                MailView(isShowing: $isShowingMailView,
                         subject: "Missing Recipe Report",
                         body: emailBody())
            }
            .alert("Report Sent", isPresented: $isShowingConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Thank you for your submission!")
            }
        }
    }

    private func sendEmail() {
        isShowingMailView = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isShowingConfirmation = true
        }
    }

    private func emailBody() -> String {
        "Recipe Name: \(recipeName)\n\nAdditional Information:\n\(additionalInfo)"
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
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

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
