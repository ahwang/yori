//
//  AccountSelectionView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct AccountSelectionView: View {
    let accounts: [ConnectedAccount]
    @Binding var showAccountSelection: Bool
    @Binding var showPlaidConnection: Bool
    @State private var selectedAccounts: Set<String> = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Select Accounts")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Choose which accounts you'd like to track in Yori. You can always add or remove accounts later.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)

                // Accounts list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(accounts, id: \.id) { account in
                            AccountSelectionRow(
                                account: account,
                                isSelected: selectedAccounts.contains(account.id)
                            ) {
                                toggleAccountSelection(account.id)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Bottom section
                VStack(spacing: 16) {
                    // Selection summary
                    if !selectedAccounts.isEmpty {
                        HStack {
                            Text("\(selectedAccounts.count) account\(selectedAccounts.count == 1 ? "" : "s") selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        // Continue button
                        Button(action: {
                            saveSelectedAccounts()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(selectedAccounts.isEmpty ? "Continue without accounts" : "Save & Continue")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(selectedAccounts.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)

                        // Select all/none buttons
                        HStack(spacing: 20) {
                            Button(action: selectAllAccounts) {
                                Text("Select All")
                                    .foregroundColor(.blue)
                            }

                            Button(action: deselectAllAccounts) {
                                Text("Select None")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        showAccountSelection = false
                    }
                }
            }
        }
        .onAppear {
            // Pre-select all accounts by default
            selectedAccounts = Set(accounts.map { $0.id })
        }
        .alert("Success", isPresented: $showAlert) {
            Button("OK") {
                showAccountSelection = false
                showPlaidConnection = false
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func toggleAccountSelection(_ accountId: String) {
        if selectedAccounts.contains(accountId) {
            selectedAccounts.remove(accountId)
        } else {
            selectedAccounts.insert(accountId)
        }
    }

    private func selectAllAccounts() {
        selectedAccounts = Set(accounts.map { $0.id })
    }

    private func deselectAllAccounts() {
        selectedAccounts.removeAll()
    }

    private func saveSelectedAccounts() {
        isLoading = true

        // Simulate API call to save selected accounts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false

            if selectedAccounts.isEmpty {
                alertMessage = "You can add accounts anytime from Settings."
            } else {
                alertMessage = "Successfully connected \(selectedAccounts.count) account\(selectedAccounts.count == 1 ? "" : "s")!"
            }
            showAlert = true
        }

        // TODO: Implement actual backend call
        // This would send the selected account IDs to your backend
        // POST /api/user/accounts/select
        // Headers: Authorization: Bearer {firebase_token}
        // Body: { "selected_account_ids": [...] }
    }

    private func saveToBackend() {
        guard let user = Auth.auth().currentUser else { return }

        user.getIDToken { idToken, error in
            guard let idToken = idToken, error == nil else {
                alertMessage = "Authentication error"
                showAlert = true
                return
            }

            // TODO: Make API call to your backend
            // let selectedAccountIds = Array(selectedAccounts)
            // ApiService.saveSelectedAccounts(token: idToken, accountIds: selectedAccountIds)
        }
    }
}

struct AccountSelectionRow: View {
    let account: ConnectedAccount
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Account icon
                Image(systemName: accountIcon)
                    .font(.title2)
                    .foregroundColor(accountColor)
                    .frame(width: 40)

                // Account details
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(account.institution)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Balance
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(account.balance))
                        .font(.headline)
                        .foregroundColor(account.balance >= 0 ? .primary : .red)

                    Text(account.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var accountIcon: String {
        switch account.type.lowercased() {
        case "checking":
            return "banknote"
        case "savings":
            return "dollarsign.bank.building"
        case "credit":
            return "creditcard"
        default:
            return "building.columns"
        }
    }

    private var accountColor: Color {
        switch account.type.lowercased() {
        case "checking":
            return .blue
        case "savings":
            return .green
        case "credit":
            return .orange
        default:
            return .gray
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
    }
}

#Preview {
    AccountSelectionView(
        accounts: [
            ConnectedAccount(id: "1", name: "Chase Checking", type: "checking", balance: 2450.30, institution: "Chase Bank"),
            ConnectedAccount(id: "2", name: "Chase Savings", type: "savings", balance: 8750.50, institution: "Chase Bank"),
            ConnectedAccount(id: "3", name: "Chase Freedom Card", type: "credit", balance: -1250.75, institution: "Chase Bank")
        ],
        showAccountSelection: .constant(true),
        showPlaidConnection: .constant(true)
    )
}
