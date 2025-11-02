//
//  DashboardCards.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import SwiftUI

// MARK: - Net Worth Card
struct NetWorthCard: View {
    let netWorth: Double
    let changePercent: Double
    let lastUpdated: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Net Worth")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Updated \(timeAgoString(from: lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(formatCurrency(netWorth))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack(spacing: 6) {
                    Image(systemName: changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(changePercent >= 0 ? .green : .red)
                        .font(.caption)

                    Text("\(changePercent >= 0 ? "+" : "")\(String(format: "%.1f", changePercent))% this month")
                        .font(.subheadline)
                        .foregroundColor(changePercent >= 0 ? .green : .red)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Assets & Liabilities Card
struct AssetsLiabilitiesCard: View {
    let totalAssets: Double
    let totalLiabilities: Double

    var body: some View {
        VStack(spacing: 16) {
            Text("Assets & Liabilities")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                // Assets
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("Assets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(formatCurrency(totalAssets))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)

                // Liabilities
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.red)
                        Text("Liabilities")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(formatCurrency(totalLiabilities))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Asset Breakdown Card
struct AssetBreakdownCard: View {
    let assetCategories: [AssetCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Breakdown")
                .font(.headline)
                .foregroundColor(.secondary)

            if assetCategories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.title)
                        .foregroundColor(.gray)

                    Text("No assets to display")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(assetCategories.indices, id: \.self) { index in
                        AssetCategoryRow(category: assetCategories[index])
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

struct AssetCategoryRow: View {
    let category: AssetCategory

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
                    .font(.system(size: 18))
            }

            // Category details
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(category.accounts.count) account\(category.accounts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(category.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(String(format: "%.1f", category.percentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: String {
        guard let assetType = AssetType.allCases.first(where: { $0.rawValue == category.name }) else {
            return "folder"
        }
        return assetType.icon
    }

    private var categoryColor: Color {
        switch category.color {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "yellow":
            return .yellow
        default:
            return .gray
        }
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                NavigationLink(destination: AccountsView()) {
                    QuickActionRow(
                        icon: "building.columns",
                        title: "Manage Accounts",
                        subtitle: "View and manage linked accounts",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // TODO: Add transaction functionality
                }) {
                    QuickActionRow(
                        icon: "plus.circle",
                        title: "Add Transaction",
                        subtitle: "Record a manual transaction",
                        color: .green
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // TODO: Add goals functionality
                }) {
                    QuickActionRow(
                        icon: "target",
                        title: "Set Financial Goals",
                        subtitle: "Create and track your goals",
                        color: .purple
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helper Functions
private func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "$0"
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            NetWorthCard(
                netWorth: 67449.05,
                changePercent: 2.3,
                lastUpdated: Date().addingTimeInterval(-3600)
            )

            AssetsLiabilitiesCard(
                totalAssets: 68699.80,
                totalLiabilities: 1250.75
            )

            AssetBreakdownCard(
                assetCategories: [
                    AssetCategory(name: "Retirement", amount: 45000, percentage: 65.5, accounts: [], color: "purple"),
                    AssetCategory(name: "Investments", amount: 12500, percentage: 18.2, accounts: [], color: "green"),
                    AssetCategory(name: "Cash & Savings", amount: 11200.80, percentage: 16.3, accounts: [], color: "blue")
                ]
            )

            QuickActionsCard()
        }
        .padding(.horizontal, 16)
    }
}