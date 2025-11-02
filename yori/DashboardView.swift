//
//  DashboardView.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @State private var showingSignOut = false
    @State private var showingSettings = false
    @State private var financialSummary: FinancialSummary?
    @State private var isLoadingData = true

    var body: some View {
        NavigationView {
            VStack {
                if isLoadingData {
                    // Loading state
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your financial data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let summary = financialSummary {
                    // Financial dashboard
                    ScrollView {
                        VStack(spacing: 24) {
                            // Net Worth Card
                            NetWorthCard(
                                netWorth: summary.netWorth,
                                changePercent: summary.netWorthChangePercent ?? 0.0,
                                lastUpdated: summary.calculatedAt ?? Date()
                            )
                            
                            // Assets & Liabilities Summary
                            AssetsLiabilitiesCard(
                                totalAssets: summary.totalAssets,
                                totalLiabilities: summary.totalLiabilities
                            )
                            
                            // Asset Breakdown
                            AssetBreakdownCard(assetCategories: summary.assetBreakdown)
                            
                            // Quick Actions
                            QuickActionsCard()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        loadFinancialData()
                    }
                } else {
                    // No data state
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Connect Accounts to Get Started")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Link your bank accounts to see your financial overview and get AI-powered insights.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        NavigationLink(destination: AccountsView()) {
                            Text("Connect Accounts")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.primary)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            loadFinancialData()
        }
    }

    private func loadFinancialData() {
        isLoadingData = true

        Task {
            do {
                // Load financial summary from Amplify backend
                let summary = try await AmplifyAPIService.shared.getFinancialSummary()

                await MainActor.run {
                    self.financialSummary = summary
                    self.isLoadingData = false
                }
            } catch {
                print("Error loading financial data: \(error)")

                await MainActor.run {
                    self.isLoadingData = false

                    // Show mock data as fallback for development
                    self.loadMockData()
                }
            }
        }
    }

    private func loadMockData() {
        // Fallback mock data for development
        let mockAccounts = [
            ConnectedAccount(id: "1", userProfileID: nil, accountName: "Chase Checking", accountType: "checking", balance: 2450.30, institution: "Chase Bank", plaidAccountID: nil, isActive: true, lastSynced: nil, createdAt: nil, updatedAt: nil),
            ConnectedAccount(id: "2", userProfileID: nil, accountName: "Wells Fargo Savings", accountType: "savings", balance: 38750.50, institution: "Wells Fargo", plaidAccountID: nil, isActive: true, lastSynced: nil, createdAt: nil, updatedAt: nil),
            ConnectedAccount(id: "3", userProfileID: nil, accountName: "Capital One Venture", accountType: "credit", balance: -12500.75, institution: "Capital One", plaidAccountID: nil, isActive: true, lastSynced: nil, createdAt: nil, updatedAt: nil),
            ConnectedAccount(id: "4", userProfileID: nil, accountName: "Fidelity 401(k)", accountType: "retirement", balance: 450000.00, institution: "Fidelity", plaidAccountID: nil, isActive: true, lastSynced: nil, createdAt: nil, updatedAt: nil),
            ConnectedAccount(id: "5", userProfileID: nil, accountName: "E*TRADE Brokerage", accountType: "investment", balance: 1250000.00, institution: "E*TRADE", plaidAccountID: nil, isActive: true, lastSynced: nil, createdAt: nil, updatedAt: nil)
        ]

        // Calculate asset breakdown
        let assetBreakdown = calculateAssetBreakdown(from: mockAccounts)
        let totalAssets = mockAccounts.filter { $0.isAsset }.reduce(0) { $0 + $1.balance }
        let totalLiabilities = abs(mockAccounts.filter { $0.isLiability }.reduce(0) { $0 + $1.balance })

        financialSummary = FinancialSummary(
            id: nil,
            netWorth: totalAssets - totalLiabilities,
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorthChangePercent: 2.3,
            assetBreakdown: assetBreakdown,
            calculatedAt: Date(),
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func calculateAssetBreakdown(from accounts: [ConnectedAccount]) -> [AssetCategory] {
        let assetAccounts = accounts.filter { $0.isAsset }
        let totalAssets = assetAccounts.reduce(0) { $0 + $1.balance }

        let groupedByType = Dictionary(grouping: assetAccounts) { $0.assetType }

        return groupedByType.compactMap { (type, accounts) in
            let amount = accounts.reduce(0) { $0 + $1.balance }
            let percentage = totalAssets > 0 ? (amount / totalAssets) * 100 : 0

            return AssetCategory(
                name: type.rawValue,
                amount: amount,
                percentage: percentage,
                accounts: accounts.map { ConnectedAccountSummary(id: $0.id, name: $0.accountName, balance: $0.balance) },
                color: type.colorName
            )
        }.sorted { $0.amount > $1.amount }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            // Clear onboarding completion
            UserDefaults.standard.removeObject(forKey: "onboarding_completed")
            // The app will automatically show the authentication screen
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

#Preview {
    DashboardView()
}
