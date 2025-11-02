// swiftlint:disable all
import Amplify
import Foundation

public struct PlaidToken: Model {
  public let id: String
  public var itemID: String
  public var accessToken: String
  public var institutionID: String
  public var institutionName: String
  public var isActive: Bool
  public var lastUsed: Temporal.DateTime?
  public var createdAt: Temporal.DateTime
  public var updatedAt: Temporal.DateTime
  public var userProfile: UserProfile?
  
  public init(id: String = UUID().uuidString,
      itemID: String,
      accessToken: String,
      institutionID: String,
      institutionName: String,
      isActive: Bool,
      lastUsed: Temporal.DateTime? = nil,
      createdAt: Temporal.DateTime,
      updatedAt: Temporal.DateTime,
      userProfile: UserProfile? = nil) {
      self.id = id
      self.itemID = itemID
      self.accessToken = accessToken
      self.institutionID = institutionID
      self.institutionName = institutionName
      self.isActive = isActive
      self.lastUsed = lastUsed
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.userProfile = userProfile
  }
}