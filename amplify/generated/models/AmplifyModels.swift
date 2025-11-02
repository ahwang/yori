// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "f5fdfe724756e5e916d4f3932faa8f90"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: UserProfile.self)
    ModelRegistry.register(modelType: ConnectedAccount.self)
    ModelRegistry.register(modelType: PlaidToken.self)
    ModelRegistry.register(modelType: FinancialSummary.self)
  }
}