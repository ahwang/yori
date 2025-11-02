//
//  APIService.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import Foundation
import FirebaseAuth

class APIService {
    static let shared = APIService()

    // TODO: Replace with your actual API Gateway URL
    private let baseURL = "https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod"

    private init() {}

    // MARK: - Generic API Request Method

    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }

        // Get Firebase ID token
        let idToken = try await user.getIDToken()

        // Create request
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        do {
            let decodedResponse = try JSONDecoder().decode(responseType, from: data)
            return decodedResponse
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - User Profile API

    func getUserProfile() async throws -> UserProfile {
        return try await makeRequest(
            endpoint: "/user/profile",
            responseType: UserProfile.self
        )
    }

    func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        let encoder = JSONEncoder()
        let body = try encoder.encode(profile)

        return try await makeRequest(
            endpoint: "/user/profile",
            method: .PUT,
            body: body,
            responseType: UserProfile.self
        )
    }

    // MARK: - Financial Data API

    func getFinancialSummary() async throws -> FinancialSummary {
        return try await makeRequest(
            endpoint: "/user/financial-summary",
            responseType: FinancialSummary.self
        )
    }

    func getConnectedAccounts() async throws -> [ConnectedAccount] {
        let response = try await makeRequest(
            endpoint: "/user/accounts",
            responseType: AccountsResponse.self
        )
        return response.accounts
    }

    // MARK: - Plaid Integration API

    func exchangePlaidToken(_ publicToken: String) async throws -> PlaidExchangeResponse {
        let requestBody = PlaidExchangeRequest(publicToken: publicToken)
        let encoder = JSONEncoder()
        let body = try encoder.encode(requestBody)

        return try await makeRequest(
            endpoint: "/plaid/exchange-token",
            method: .POST,
            body: body,
            responseType: PlaidExchangeResponse.self
        )
    }

    func selectAccounts(_ accountIds: [String]) async throws -> SuccessResponse {
        let requestBody = SelectAccountsRequest(accountIds: accountIds)
        let encoder = JSONEncoder()
        let body = try encoder.encode(requestBody)

        return try await makeRequest(
            endpoint: "/user/accounts/select",
            method: .POST,
            body: body,
            responseType: SuccessResponse.self
        )
    }

    func disconnectAccount(_ accountId: String) async throws -> SuccessResponse {
        return try await makeRequest(
            endpoint: "/user/accounts/\(accountId)",
            method: .DELETE,
            responseType: SuccessResponse.self
        )
    }
}

// MARK: - HTTP Method Enum

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - API Error Types

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Request/Response Models

struct UserProfile: Codable {
    let userId: String
    let email: String?
    let displayName: String?
    let createdAt: String
    let onboardingCompleted: Bool
    let hasConnectedAccounts: Bool
}

struct AccountsResponse: Codable {
    let accounts: [ConnectedAccount]
}

struct PlaidExchangeRequest: Codable {
    let publicToken: String
}

struct PlaidExchangeResponse: Codable {
    let success: Bool
    let accountIds: [String]
    let message: String
}

struct SelectAccountsRequest: Codable {
    let accountIds: [String]
}

struct SuccessResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - ConnectedAccount Extension for API

extension ConnectedAccount: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, type, balance, institution
    }
}

// MARK: - FinancialSummary Extension for API

extension FinancialSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case netWorth, netWorthChangePercent, totalAssets, totalLiabilities, assetBreakdown, lastUpdated
    }
}

extension AssetCategory: Codable {
    enum CodingKeys: String, CodingKey {
        case name, amount, percentage, accounts, color
    }
}