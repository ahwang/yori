//
//  AmplifyAPIService.swift
//  yori
//
//  Created by Andrew Hwang on 11/1/25.
//

import Foundation
import Amplify
import FirebaseAuth

class AmplifyAPIService {
    static let shared = AmplifyAPIService()

    private init() {}

    // MARK: - User Profile Management

    func getCurrentUserProfile() async throws -> UserProfile {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }

        // First try to get existing profile by Firebase UID
        let request = GraphQLRequest<UserProfile?>(
            document: getUserProfileByFirebaseUIDQuery,
            variables: ["firebaseUID": user.uid],
            responseType: UserProfile?.self
        )

        let result = try await Amplify.API.query(request: request)

        switch result {
        case .success(let userProfile):
            if let profile = userProfile {
                return profile
            } else {
                // Create new profile if doesn't exist
                return try await createUserProfile(firebaseUID: user.uid, email: user.email, displayName: user.displayName)
            }
        case .failure(let error):
            throw error
        }
    }

    func createUserProfile(firebaseUID: String, email: String?, displayName: String?) async throws -> UserProfile {
        let userProfile = UserProfile(
            firebaseUID: firebaseUID,
            email: email,
            displayName: displayName,
            onboardingCompleted: false,
            hasConnectedAccounts: false,
            preferredCurrency: "USD",
            createdAt: Temporal.DateTime.now(),
            updatedAt: Temporal.DateTime.now()
        )

        let request = GraphQLRequest<UserProfile>(
            document: createUserProfileMutation,
//            variables: userProfile.graphQLVariables,
            responseType: UserProfile.self
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(let createdProfile):
            return createdProfile
        case .failure(let error):
            throw error
        }
    }

    func updateUserProfile(_ userProfile: UserProfile) async throws -> UserProfile {
        let request = GraphQLRequest<UserProfile>(
            document: updateUserProfileMutation,
//            variables: userProfile.graphQLVariables,
            responseType: UserProfile.self
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(let updatedProfile):
            return updatedProfile
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Connected Accounts

    func getConnectedAccounts() async throws -> [ConnectedAccount] {
        let userProfile = try await getCurrentUserProfile()

        let request = GraphQLRequest<[ConnectedAccount]>(
            document: listConnectedAccountsByUserQuery,
            variables: ["userProfileID": userProfile.id],
            responseType: [ConnectedAccount].self
        )

        let result = try await Amplify.API.query(request: request)

        switch result {
        case .success(let accounts):
            return accounts
        case .failure(let error):
            throw error
        }
    }

    func syncPlaidAccounts(publicToken: String) async throws -> [ConnectedAccount] {
        let userProfile = try await getCurrentUserProfile()

        let request = GraphQLRequest<[ConnectedAccount]>(
            document: syncPlaidAccountsMutation,
            variables: [
                "publicToken": publicToken,
                "userProfileID": userProfile.id
            ],
            responseType: [ConnectedAccount].self
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(let accounts):
            // Update user profile to indicate they have connected accounts
            var userProfile = try await getCurrentUserProfile()
            userProfile.hasConnectedAccounts = true
            _ = try await updateUserProfile(userProfile)

            return accounts
        case .failure(let error):
            throw error
        }
    }

    func disconnectAccount(_ accountId: String) async throws {
        let request = GraphQLRequest<ConnectedAccount?>(
            document: deleteConnectedAccountMutation,
            variables: ["id": accountId],
            responseType: ConnectedAccount?.self
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(_):
            return
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Financial Summary

    func getFinancialSummary() async throws -> FinancialSummary {
        let userProfile = try await getCurrentUserProfile()

        // First try to get existing summary
        let getRequest = GraphQLRequest<FinancialSummary?>(
            document: getFinancialSummaryQuery,
            variables: ["userProfileID": userProfile.id],
            responseType: FinancialSummary?.self
        )

        let getResult = try await Amplify.API.query(request: getRequest)

        switch getResult {
        case .success(let existingSummary):
            if let summary = existingSummary,
               Calendar.current.isDateInToday(summary.calculatedAt.foundationDate) {
                // Return existing summary if calculated today
                return summary
            } else {
                // Calculate new summary
                return try await calculateFinancialSummary(for: userProfile.id)
            }
        case .failure(let error):
            throw error
        }
    }

    private func calculateFinancialSummary(for userProfileID: String) async throws -> FinancialSummary {
        let request = GraphQLRequest<FinancialSummary>(
            document: calculateFinancialSummaryMutation,
            variables: ["userProfileID": userProfileID],
            responseType: FinancialSummary.self
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(let summary):
            return summary
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - GraphQL Queries and Mutations

private let getUserProfileByFirebaseUIDQuery = """
query GetUserProfileByFirebaseUID($firebaseUID: String!) {
  getUserProfileByFirebaseUID(firebaseUID: $firebaseUID) {
    id
    firebaseUID
    email
    displayName
    onboardingCompleted
    hasConnectedAccounts
    preferredCurrency
    createdAt
    updatedAt
  }
}
"""

private let createUserProfileMutation = """
mutation CreateUserProfile($input: CreateUserProfileInput!) {
  createUserProfile(input: $input) {
    id
    firebaseUID
    email
    displayName
    onboardingCompleted
    hasConnectedAccounts
    preferredCurrency
    createdAt
    updatedAt
  }
}
"""

private let updateUserProfileMutation = """
mutation UpdateUserProfile($input: UpdateUserProfileInput!) {
  updateUserProfile(input: $input) {
    id
    firebaseUID
    email
    displayName
    onboardingCompleted
    hasConnectedAccounts
    preferredCurrency
    createdAt
    updatedAt
  }
}
"""

private let listConnectedAccountsByUserQuery = """
query GetActiveConnectedAccounts($userProfileID: ID!) {
  getActiveConnectedAccounts(userProfileID: $userProfileID) {
    id
    accountName
    accountType
    balance
    institution
    isActive
    lastSynced
    createdAt
    updatedAt
  }
}
"""

private let syncPlaidAccountsMutation = """
mutation SyncPlaidAccounts($publicToken: String!, $userProfileID: ID!) {
  syncPlaidAccounts(publicToken: $publicToken, userProfileID: $userProfileID) {
    id
    accountName
    accountType
    balance
    institution
    isActive
    createdAt
  }
}
"""

private let deleteConnectedAccountMutation = """
mutation DeleteConnectedAccount($input: DeleteConnectedAccountInput!) {
  deleteConnectedAccount(input: $input) {
    id
  }
}
"""

private let getFinancialSummaryQuery = """
query GetFinancialSummary($userProfileID: ID!) {
  getFinancialSummaryForUser(userProfileID: $userProfileID) {
    id
    netWorth
    totalAssets
    totalLiabilities
    netWorthChangePercent
    assetBreakdown
    calculatedAt
    createdAt
    updatedAt
  }
}
"""

private let calculateFinancialSummaryMutation = """
mutation CalculateFinancialSummary($userProfileID: ID!) {
  calculateFinancialSummary(userProfileID: $userProfileID) {
    id
    netWorth
    totalAssets
    totalLiabilities
    netWorthChangePercent
    assetBreakdown
    calculatedAt
    createdAt
    updatedAt
  }
}
"""

// MARK: - Note: Data models are now generated in API.swift
// This service uses the generated GraphQL models from Amplify codegen

// MARK: - API Error Extension

//extension APIError {
//    static func amplifyError<T>(_ error: GraphQLResponseError<T>) -> APIError {
//        return .decodingError(error)
//    }
//}

// MARK: - Date Extensions for GraphQL

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
