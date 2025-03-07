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
    @State private var additionalInfo: String = "Add details..."
    @State private var isShowingMailView = false
    @State private var isShowingConfirmation = false
    
    var body: some View {
        ZStack {
            // Conditional background: system background in light mode, gradient in dark mode.
            if colorScheme == .light {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "00AA00").opacity(0.3),
                        Color(hex: "008800").opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            Form {
                Section(header: Text("Missing Recipe Details")) {
                    TextField("Recipe Name", text: $recipeName)
                    TextEditor(text: $additionalInfo)
                        .onChange(of: additionalInfo) { newValue in
                            if newValue.isEmpty {
                                additionalInfo = "Add details..."
                            }
                        }
                        .frame(height: 150)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 0.5))
                        .foregroundColor(additionalInfo == "Add details..." ? .gray : .primary)
                }
                
                Section {
                    Button(action: sendEmail) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(Color.blue)
                            Text("Send Report")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(recipeName.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Report Missing Recipe")
        .sheet(isPresented: $isShowingMailView) {
            MailView(isShowing: $isShowingMailView, subject: "Missing Recipe Report", body: emailBody())
        }
        .alert(isPresented: $isShowingConfirmation) {
            Alert(title: Text("Report Sent"), message: Text("Thank you for your submission!"), dismissButton: .default(Text("OK")))
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

struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    var subject: String
    var body: String
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        
        init(parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
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
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
