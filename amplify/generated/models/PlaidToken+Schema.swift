// swiftlint:disable all
import Amplify
import Foundation

extension PlaidToken {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case itemID
    case accessToken
    case institutionID
    case institutionName
    case isActive
    case lastUsed
    case createdAt
    case updatedAt
    case userProfile
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let plaidToken = PlaidToken.keys
    
    model.authRules = [
      rule(allow: .public, operations: [.create, .read, .update, .delete])
    ]
    
    model.listPluralName = "PlaidTokens"
    model.syncPluralName = "PlaidTokens"
    
    model.attributes(
      .index(fields: ["userProfileID"], name: "byUserProfile"),
      .primaryKey(fields: [plaidToken.id])
    )
    
    model.fields(
      .field(plaidToken.id, is: .required, ofType: .string),
      .field(plaidToken.itemID, is: .required, ofType: .string),
      .field(plaidToken.accessToken, is: .required, ofType: .string),
      .field(plaidToken.institutionID, is: .required, ofType: .string),
      .field(plaidToken.institutionName, is: .required, ofType: .string),
      .field(plaidToken.isActive, is: .required, ofType: .bool),
      .field(plaidToken.lastUsed, is: .optional, ofType: .dateTime),
      .field(plaidToken.createdAt, is: .required, ofType: .dateTime),
      .field(plaidToken.updatedAt, is: .required, ofType: .dateTime),
      .belongsTo(plaidToken.userProfile, is: .optional, ofType: UserProfile.self, targetNames: ["userProfileID"])
    )
    }
}

extension PlaidToken: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}