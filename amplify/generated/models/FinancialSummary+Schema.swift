// swiftlint:disable all
import Amplify
import Foundation

extension FinancialSummary {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case netWorth
    case totalAssets
    case totalLiabilities
    case netWorthChangePercent
    case assetBreakdown
    case calculatedAt
    case createdAt
    case updatedAt
    case userProfile
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let financialSummary = FinancialSummary.keys
    
    model.authRules = [
      rule(allow: .public, operations: [.create, .read, .update, .delete])
    ]
    
    model.listPluralName = "FinancialSummaries"
    model.syncPluralName = "FinancialSummaries"
    
    model.attributes(
      .index(fields: ["userProfileID"], name: "byUserProfile"),
      .primaryKey(fields: [financialSummary.id])
    )
    
    model.fields(
      .field(financialSummary.id, is: .required, ofType: .string),
      .field(financialSummary.netWorth, is: .required, ofType: .double),
      .field(financialSummary.totalAssets, is: .required, ofType: .double),
      .field(financialSummary.totalLiabilities, is: .required, ofType: .double),
      .field(financialSummary.netWorthChangePercent, is: .optional, ofType: .double),
      .field(financialSummary.assetBreakdown, is: .optional, ofType: .string),
      .field(financialSummary.calculatedAt, is: .required, ofType: .dateTime),
      .field(financialSummary.createdAt, is: .required, ofType: .dateTime),
      .field(financialSummary.updatedAt, is: .required, ofType: .dateTime),
      .belongsTo(financialSummary.userProfile, is: .optional, ofType: UserProfile.self, targetNames: ["userProfileID"])
    )
    }
}

extension FinancialSummary: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}