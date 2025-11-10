//
//  PlaidConnectionView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth
import Amplify
import LinkKit

struct PlaidConnectionView: View {
    @Binding var showPlaidConnection: Bool
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var connectedAccounts: [ConnectedAccount] = []
    @State private var showAccountSelection = false
    @State private var showPlaidLink = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Header
            VStack(spacing: 20) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                VStack(spacing: 12) {
                    Text("Connect Your Bank")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Securely connect your financial accounts to get personalized insights and recommendations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            // Benefits list
            VStack(alignment: .leading, spacing: 16) {
                BenefitRow(icon: "lock.shield", text: "Bank-level security with 256-bit encryption")
                BenefitRow(icon: "eye.slash", text: "Read-only access - we never store credentials")
                BenefitRow(icon: "checkmark.seal", text: "Trusted by millions of users")
                BenefitRow(icon: "clock", text: "Real-time account updates")
            }
            .padding(.horizontal, 30)

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                // Connect button
                Button(action: {
                    connectWithPlaid()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("Connect Bank Account")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding(.horizontal, 30)

                // Manual entry option
                Button(action: {
                    // TODO: Implement manual entry flow
                    alertMessage = "Manual entry option coming soon!"
                    showAlert = true
                }) {
                    Text("I'll add accounts manually")
                        .foregroundColor(.blue)
                }

                // Skip option
                Button(action: {
                    showPlaidConnection = false
                }) {
                    Text("Skip for now")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
        .alert("Connection Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showAccountSelection) {
            AccountSelectionView(
                accounts: connectedAccounts,
                showAccountSelection: $showAccountSelection,
                showPlaidConnection: $showPlaidConnection
            )
        }
        .background(
            PlaidLinkViewController(
                isPresented: $showPlaidLink,
                onSuccess: { publicToken in
                    isLoading = false
                    sendTokenToBackend(publicToken)
                },
                onExit: { error in
                    isLoading = false
                    if let error = error {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            )
        )
    }

    private func connectWithPlaid() {
        isLoading = true
        showPlaidLink = true
    }

    private func sendTokenToBackend(_ publicToken: String) {
        Task {
            do {
                // Sync Plaid accounts using Amplify
                let accounts = try await AmplifyAPIService.shared.syncPlaidAccounts(publicToken: publicToken)

                await MainActor.run {
                    self.connectedAccounts = accounts
                    self.showAccountSelection = true
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to connect accounts: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}


// MARK: - Plaid Link UIViewController Wrapper

struct PlaidLinkViewController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSuccess: (String) -> Void
    let onExit: (Error?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && context.coordinator.handler == nil {
            context.coordinator.presentPlaidLink(from: uiViewController)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onSuccess: onSuccess, onExit: onExit)
    }

    class Coordinator {
        @Binding var isPresented: Bool
        let onSuccess: (String) -> Void
        let onExit: (Error?) -> Void
        var handler: Handler?

        init(isPresented: Binding<Bool>, onSuccess: @escaping (String) -> Void, onExit: @escaping (Error?) -> Void) {
            self._isPresented = isPresented
            self.onSuccess = onSuccess
            self.onExit = onExit
        }

        func presentPlaidLink(from viewController: UIViewController) {
            PlaidService.shared.presentPlaidLink(
                from: viewController,
                onSuccess: { [weak self] publicToken in
                    self?.handler = nil
                    self?.isPresented = false
                    self?.onSuccess(publicToken)
                },
                onExit: { [weak self] error in
                    self?.handler = nil
                    self?.isPresented = false
                    self?.onExit(error)
                }
            )
        }
    }
}

#Preview {
    PlaidConnectionView(showPlaidConnection: .constant(true))
}
