// swiftlint:disable all
import Amplify
import Foundation

extension ConnectedAccount {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case accountName
    case accountType
    case balance
    case institution
    case plaidAccountID
    case plaidItemID
    case isActive
    case lastSynced
    case createdAt
    case updatedAt
    case userProfile
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let connectedAccount = ConnectedAccount.keys
    
    model.authRules = [
      rule(allow: .public, operations: [.create, .read, .update, .delete])
    ]
    
    model.listPluralName = "ConnectedAccounts"
    model.syncPluralName = "ConnectedAccounts"
    
    model.attributes(
      .index(fields: ["userProfileID"], name: "byUserProfile"),
      .primaryKey(fields: [connectedAccount.id])
    )
    
    model.fields(
      .field(connectedAccount.id, is: .required, ofType: .string),
      .field(connectedAccount.accountName, is: .required, ofType: .string),
      .field(connectedAccount.accountType, is: .required, ofType: .enum(type: AccountType.self)),
      .field(connectedAccount.balance, is: .required, ofType: .double),
      .field(connectedAccount.institution, is: .required, ofType: .string),
      .field(connectedAccount.plaidAccountID, is: .optional, ofType: .string),
      .field(connectedAccount.plaidItemID, is: .optional, ofType: .string),
      .field(connectedAccount.isActive, is: .required, ofType: .bool),
      .field(connectedAccount.lastSynced, is: .optional, ofType: .dateTime),
      .field(connectedAccount.createdAt, is: .required, ofType: .dateTime),
      .field(connectedAccount.updatedAt, is: .required, ofType: .dateTime),
      .belongsTo(connectedAccount.userProfile, is: .optional, ofType: UserProfile.self, targetNames: ["userProfileID"])
    )
    }
}

extension ConnectedAccount: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}