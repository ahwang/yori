//
//  SettingsView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOut = false

    var body: some View {
        NavigationView {
            List {
                // App Settings Section
                Section {
                    NavigationLink(destination: Text("Notifications Settings")) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Notifications")
                        }
                    }

                    NavigationLink(destination: Text("Privacy Settings")) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Privacy")
                        }
                    }

                    NavigationLink(destination: Text("Security Settings")) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Security")
                        }
                    }
                } header: {
                    Text("App Settings")
                }

                // Support Section
                Section {
                    Button(action: {
                        // TODO: Open help/support
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("Help & Support")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }

                    Button(action: {
                        // TODO: Open feedback
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Send Feedback")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Support")
                }

                // Account Section
                Section {
                    Button(action: {
                        showingSignOut = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOut) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }


    private func signOut() {
        do {
            try Auth.auth().signOut()
            // Clear onboarding completion
            UserDefaults.standard.removeObject(forKey: "onboarding_completed")
            dismiss()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct ConnectedAccountRow: View {
    let account: ConnectedAccount

    var body: some View {
        HStack(spacing: 12) {
            // Account icon
            Image(systemName: accountIcon)
                .font(.title2)
                .foregroundColor(accountColor)
                .frame(width: 24)

            // Account details
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName)
                    .font(.headline)

                Text(account.institution)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Balance
            Text(formatCurrency(account.balance))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(account.balance >= 0 ? .primary : .red)
        }
        .padding(.vertical, 4)
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
    SettingsView()
}
