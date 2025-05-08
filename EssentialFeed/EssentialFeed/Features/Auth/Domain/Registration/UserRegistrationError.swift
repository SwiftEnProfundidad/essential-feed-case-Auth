
import Foundation

public enum UserRegistrationError: Error, Equatable {
    case connectivity
    case invalidData
    case emailAlreadyInUse
    case unknown
}
