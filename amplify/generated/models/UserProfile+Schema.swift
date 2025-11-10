// swiftlint:disable all
import Amplify
import Foundation

extension UserProfile {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case firebaseUID
    case email
    case displayName
    case onboardingCompleted
    case hasConnectedAccounts
    case preferredCurrency
    case createdAt
    case updatedAt
    case connectedAccounts
    case financialSummaries
    case plaidTokens
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let userProfile = UserProfile.keys
    
    model.authRules = [
      rule(allow: .public, operations: [.create, .read, .update, .delete])
    ]
    
    model.listPluralName = "UserProfiles"
    model.syncPluralName = "UserProfiles"
    
    model.attributes(
      .index(fields: ["firebaseUID"], name: "byFirebaseUID"),
      .primaryKey(fields: [userProfile.id])
    )
    
    model.fields(
      .field(userProfile.id, is: .required, ofType: .string),
      .field(userProfile.firebaseUID, is: .optional, ofType: .string),
      .field(userProfile.email, is: .optional, ofType: .string),
      .field(userProfile.displayName, is: .optional, ofType: .string),
      .field(userProfile.onboardingCompleted, is: .optional, ofType: .bool),
      .field(userProfile.hasConnectedAccounts, is: .optional, ofType: .bool),
      .field(userProfile.preferredCurrency, is: .optional, ofType: .string),
      .field(userProfile.createdAt, is: .optional, ofType: .dateTime),
      .field(userProfile.updatedAt, is: .optional, ofType: .dateTime),
      .hasMany(userProfile.connectedAccounts, is: .optional, ofType: ConnectedAccount.self, associatedWith: ConnectedAccount.keys.userProfile),
      .hasMany(userProfile.financialSummaries, is: .optional, ofType: FinancialSummary.self, associatedWith: FinancialSummary.keys.userProfile),
      .hasMany(userProfile.plaidTokens, is: .optional, ofType: PlaidToken.self, associatedWith: PlaidToken.keys.userProfile)
    )
    }
}

extension UserProfile: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}