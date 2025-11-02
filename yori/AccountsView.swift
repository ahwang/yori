//
//  AccountsView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth
import Amplify

struct AccountsView: View {
    @State private var connectedAccounts: [ConnectedAccount] = []
    @State private var isLoadingAccounts = false
    @State private var showingPlaidConnection = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if connectedAccounts.isEmpty && !isLoadingAccounts {
                    // Empty state
                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 16) {
                            Image(systemName: "building.columns.circle")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)

                            VStack(spacing: 8) {
                                Text("No Accounts Connected")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("Connect your bank accounts to get personalized financial insights and AI-powered recommendations.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }

                        // Connect button
                        Button(action: {
                            showingPlaidConnection = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Connect Bank Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)

                        Spacer()
                    }
                } else {
                    // Connected accounts list
                    List {
                        Section {
                            ForEach(connectedAccounts, id: \.id) { account in
                                AccountManagementRow(
                                    account: account,
                                    onDisconnect: {
                                        disconnectAccount(account)
                                    }
                                )
                            }
                        } header: {
                            HStack {
                                Text("Connected Accounts")
                                Spacer()
                                Text("\(connectedAccounts.count) account\(connectedAccounts.count == 1 ? "" : "s")")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        } footer: {
                            Text("Your account data is encrypted and secure. We use read-only access and never store your login credentials.")
                        }

                        // Add more accounts section
                        Section {
                            Button(action: {
                                showingPlaidConnection = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Link Another Account")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text("Add more bank accounts or credit cards")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }

                if isLoadingAccounts {
                    ProgressView("Loading accounts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !connectedAccounts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingPlaidConnection = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadConnectedAccounts()
        }
        .sheet(isPresented: $showingPlaidConnection) {
            PlaidConnectionView(showPlaidConnection: $showingPlaidConnection)
        }
        .alert("Account Management", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .refreshable {
            loadConnectedAccounts()
        }
    }

    private func loadConnectedAccounts() {
        isLoadingAccounts = true

        Task {
            do {
                // Load connected accounts from Amplify
                let accounts = try await AmplifyAPIService.shared.getConnectedAccounts()

                await MainActor.run {
                    self.connectedAccounts = accounts
                    self.isLoadingAccounts = false
                }
            } catch {
                print("Error loading accounts: \(error)")

                await MainActor.run {
                    self.isLoadingAccounts = false

                    // Show mock data as fallback for development
                    self.loadMockAccounts()
                }
            }
        }
    }

    private func loadMockAccounts() {
        // Fallback mock data for development
        connectedAccounts = [
            ConnectedAccount(
                id: "acc_1",
                accountName: "Chase Checking",
                accountType: .checking,
                balance: 2450.30,
                institution: "Chase Bank",
                plaidAccountID: "Chase Bank",
                plaidItemID: nil,
                isActive: true,
                lastSynced: nil,
                createdAt: Temporal.DateTime.now(),
                updatedAt: Temporal.DateTime.now()
            ),
            ConnectedAccount(
                id: "acc_2",
                accountName: "Wells Fargo Savings",
                accountType: .savings,
                balance: 8750.50,
                institution: "Wells Fargo",
                plaidAccountID: nil,
                plaidItemID: nil,
                isActive: true,
                lastSynced: Temporal.DateTime.now(),
                createdAt: Temporal.DateTime.now(),
                updatedAt: Temporal.DateTime.now()
            )
        ]
    }

    private func disconnectAccount(_ account: ConnectedAccount) {
        Task {
            do {
                // Disconnect account using Amplify
                try await AmplifyAPIService.shared.disconnectAccount(account.id)

                await MainActor.run {
                    // Remove from local array
                    if let index = self.connectedAccounts.firstIndex(where: { $0.id == account.id }) {
                        self.connectedAccounts.remove(at: index)
                    }

                    self.alertMessage = "Account '\(account.accountName)' has been disconnected."
                    self.showAlert = true
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to disconnect account: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}

struct AccountManagementRow: View {
    let account: ConnectedAccount
    let onDisconnect: () -> Void
    @State private var showingDisconnectConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Account icon
                ZStack {
                    Circle()
                        .fill(accountColor.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: accountIcon)
                        .font(.title2)
                        .foregroundColor(accountColor)
                }

                // Account details
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.accountName)
                        .font(.headline)

                    Text(account.institution)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(account.accountType.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(accountColor.opacity(0.1))
                        .foregroundColor(accountColor)
                        .cornerRadius(4)
                }

                Spacer()

                // Balance
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(account.balance))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(account.balance >= 0 ? .primary : .red)

                    Text("Current Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    // TODO: View account details/transactions
                }) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("View Details")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                Button(action: {
                    showingDisconnectConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Disconnect")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
        .alert("Disconnect Account", isPresented: $showingDisconnectConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                onDisconnect()
            }
        } message: {
            Text("Are you sure you want to disconnect '\(account.accountName)'? This will remove all data associated with this account.")
        }
    }

    private var accountIcon: String {
        switch account.accountType {
        case .checking:
            return "banknote"
        case .savings:
            return "dollarsign.bank.building"
        case .creditCard:
            return "creditcard"
        default:
            return "building.columns"
        }
    }

    private var accountColor: Color {
        switch account.accountType {
        case .checking:
            return .blue
        case .savings:
            return .green
        case .creditCard:
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
    AccountsView()
}
