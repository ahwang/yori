// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "d5702d6b98412dd1233b241cb2c703f9"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: UserProfile.self)
    ModelRegistry.register(modelType: ConnectedAccount.self)
    ModelRegistry.register(modelType: PlaidToken.self)
    ModelRegistry.register(modelType: FinancialSummary.self)
  }
}