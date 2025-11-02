// swiftlint:disable all
import Amplify
import Foundation

public struct ConnectedAccount: Model {
  public let id: String
  public var accountName: String
  public var accountType: AccountType
  public var balance: Double
  public var institution: String
  public var plaidAccountID: String?
  public var plaidItemID: String?
  public var isActive: Bool
  public var lastSynced: Temporal.DateTime?
  public var createdAt: Temporal.DateTime
  public var updatedAt: Temporal.DateTime
  public var userProfile: UserProfile?
  
  public init(id: String = UUID().uuidString,
      accountName: String,
      accountType: AccountType,
      balance: Double,
      institution: String,
      plaidAccountID: String? = nil,
      plaidItemID: String? = nil,
      isActive: Bool,
      lastSynced: Temporal.DateTime? = nil,
      createdAt: Temporal.DateTime,
      updatedAt: Temporal.DateTime,
      userProfile: UserProfile? = nil) {
      self.id = id
      self.accountName = accountName
      self.accountType = accountType
      self.balance = balance
      self.institution = institution
      self.plaidAccountID = plaidAccountID
      self.plaidItemID = plaidItemID
      self.isActive = isActive
      self.lastSynced = lastSynced
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.userProfile = userProfile
  }
}