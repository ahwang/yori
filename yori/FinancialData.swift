//
//  FinancialData.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import Foundation

struct AssetCategory: Codable {
    let name: String
    let amount: Double
    let percentage: Double
    let accounts: [ConnectedAccountSummary]
    let color: String
}

struct ConnectedAccountSummary: Codable {
    let id: String
    let name: String
    let balance: Double
}

enum AssetType: String, CaseIterable {
    case cashAndSavings = "Cash & Savings"
    case investments = "Investments"
    case realEstate = "Real Estate"
    case retirement = "Retirement"
    case loans = "Loans"
    case creditcards = "Credit Cards"
    case other = "Other Assets"

    var icon: String {
        switch self {
        case .cashAndSavings:
            return "dollarsign.bank.building"
        case .investments:
            return "chart.line.uptrend.xyaxis"
        case .realEstate:
            return "house"
        case .retirement:
            return "calendar.badge.clock"
        case .loans:
            return "bag.circle.fill"
        case .creditcards:
            return "creditcard"
        case .other:
            return "folder"
        }
    }

    var colorName: String {
        switch self {
        case .cashAndSavings:
            return "blue"
        case .investments:
            return "green"
        case .realEstate:
            return "orange"
        case .retirement:
            return "purple"
        case .loans:
            return "yellow"
        case .creditcards:
            return "red"
        case .other:
            return "gray"
        }
    }
}

extension ConnectedAccount {
    var assetType: AssetType {
        switch accountType {
        case .checking, .savings:
            return .cashAndSavings
        case .investment:
            return .investments
        case .retirement:
            return .retirement
        case .creditCard, .loan, .mortgage:
            return .creditcards
        default:
            return .other
        }
    }

    var isAsset: Bool {
        return balance >= 0
    }

    var isLiability: Bool {
        return balance < 0
    }
}
