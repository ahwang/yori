// swiftlint:disable all
import Amplify
import Foundation

public struct FinancialSummary: Model {
  public let id: String
  public var netWorth: Double
  public var totalAssets: Double
  public var totalLiabilities: Double
  public var netWorthChangePercent: Double?
  public var assetBreakdown: String?
  public var calculatedAt: Temporal.DateTime
  public var createdAt: Temporal.DateTime
  public var updatedAt: Temporal.DateTime
  public var userProfile: UserProfile?
  
  public init(id: String = UUID().uuidString,
      netWorth: Double,
      totalAssets: Double,
      totalLiabilities: Double,
      netWorthChangePercent: Double? = nil,
      assetBreakdown: String? = nil,
      calculatedAt: Temporal.DateTime,
      createdAt: Temporal.DateTime,
      updatedAt: Temporal.DateTime,
      userProfile: UserProfile? = nil) {
      self.id = id
      self.netWorth = netWorth
      self.totalAssets = totalAssets
      self.totalLiabilities = totalLiabilities
      self.netWorthChangePercent = netWorthChangePercent
      self.assetBreakdown = assetBreakdown
      self.calculatedAt = calculatedAt
      self.createdAt = createdAt
      self.updatedAt = updatedAt
      self.userProfile = userProfile
  }
}