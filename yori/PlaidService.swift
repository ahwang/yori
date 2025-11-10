//
//  PlaidService.swift
//  yori
//
//  Plaid Link integration service
//

import Foundation
import LinkKit
import Amplify

class PlaidService: NSObject {
    static let shared = PlaidService()

    private var linkHandler: Handler?
    private var onSuccessCallback: ((String) -> Void)?
    private var onExitCallback: ((Error?) -> Void)?

    private override init() {
        super.init()
    }

    /// Create link token from backend and present Plaid Link
    func presentPlaidLink(
        from viewController: UIViewController,
        onSuccess: @escaping (String) -> Void,
        onExit: @escaping (Error?) -> Void
    ) {
        self.onSuccessCallback = onSuccess
        self.onExitCallback = onExit

        // Get link token from backend
        Task {
            do {
                let linkToken = try await createLinkToken()

                await MainActor.run {
                    self.setupPlaidLink(linkToken: linkToken, from: viewController)
                }
            } catch {
                print("Error creating link token: \(error)")
                await MainActor.run {
                    onExit(error)
                }
            }
        }
    }

    /// Create link token via backend
    private func createLinkToken() async throws -> String {
        let userProfile = try await AmplifyAPIService.shared.getCurrentUserProfile()

        let request = GraphQLRequest<CreateLinkTokenResponse>(
            document: createPlaidLinkTokenMutation,
            variables: ["userProfileID": userProfile.id],
            responseType: CreateLinkTokenResponse.self,
            decodePath: "createPlaidLinkToken"
        )

        let result = try await Amplify.API.mutate(request: request)

        switch result {
        case .success(let response):
            return response.linkToken
        case .failure(let error):
            throw error
        }
    }

    /// Setup and present Plaid Link with link token
    private func setupPlaidLink(linkToken: String, from viewController: UIViewController) {
        var linkConfiguration = LinkTokenConfiguration(token: linkToken) { [weak self] success in
            // Handle successful link
            print("Plaid Link success: \(success.publicToken)")
            self?.onSuccessCallback?(success.publicToken)
        }

        linkConfiguration.onExit = { [weak self] exit in
            // Handle user exit or error
            if let error = exit.error {
                print("Plaid Link exit with error: \(error)")
                self?.onExitCallback?(PlaidError.linkFailed(error.localizedDescription))
            } else {
                print("Plaid Link exit: User cancelled")
                self?.onExitCallback?(nil)
            }
        }

        linkConfiguration.onEvent = { event in
            // Log events for analytics
            print("Plaid Link event: \(event.eventName)")
        }

        let result = Plaid.create(linkConfiguration)

        switch result {
        case .success(let handler):
            self.linkHandler = handler
            handler.open(presentUsing: .viewController(viewController))

        case .failure(let error):
            print("Failed to create Plaid Link handler: \(error)")
            onExitCallback?(PlaidError.initializationFailed(error.localizedDescription))
        }
    }
}

// MARK: - Response Models

private struct CreateLinkTokenResponse: Decodable {
    let linkToken: String
    let expiration: String?
}

// MARK: - GraphQL Mutations

private let createPlaidLinkTokenMutation = """
mutation CreatePlaidLinkToken($userProfileID: ID!) {
  createPlaidLinkToken(userProfileID: $userProfileID) {
    linkToken
    expiration
  }
}
"""

// MARK: - Errors

enum PlaidError: LocalizedError {
    case initializationFailed(String)
    case linkFailed(String)
    case tokenCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Failed to initialize Plaid Link: \(message)"
        case .linkFailed(let message):
            return "Plaid Link failed: \(message)"
        case .tokenCreationFailed(let message):
            return "Failed to create link token: \(message)"
        }
    }
}
