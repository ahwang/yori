// swiftlint:disable all
import Amplify
import Foundation

public struct UserProfile: Model {
  public let id: String
  public var firebaseUID: String?
  public var email: String?
  public var displayName: String?
  public var onboardingCompleted: Bool?
  public var hasConnectedAccounts: Bool?
  public var preferredCurrency: String?
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  public var connectedAccounts: List<ConnectedAccount>?
  public var financialSummaries: List<FinancialSummary>?
  public var plaidTokens: List<PlaidToken>?
  
  public init(id: String = UUID().uuidString,
      firebaseUID: String? = nil,
      email: String? = nil,
      displayName: String? = nil,
      onboardingCompleted: Bool? = nil,
      hasConnectedAccounts: Bool? = nil,
      preferredCurrency: String? = nil,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil,
      connectedAccounts: List<ConnectedAccount>? = [],
      financialSummaries: List<FinancialSummary>? = [],
      plaidTokens: List<PlaidToken>? = []) {
      self.id = id
      self.firebaseUID = firebaseUID
      self.email = email
      self.displayName = displayName
      self.onboardingCompleted = onboardingCompleted
      self.hasConnectedAccounts = hasConnectedAccounts
      self.preferredCurrency = preferredCurrency
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.connectedAccounts = connectedAccounts
      self.financialSummaries = financialSummaries
      self.plaidTokens = plaidTokens
  }
}