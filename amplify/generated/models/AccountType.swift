// swiftlint:disable all
import Amplify
import Foundation

public enum AccountType: String, EnumPersistable {
  case checking = "CHECKING"
  case savings = "SAVINGS"
  case creditCard = "CREDIT_CARD"
  case investment = "INVESTMENT"
  case retirement = "RETIREMENT"
  case mortgage = "MORTGAGE"
  case loan = "LOAN"
  case other = "OTHER"
}