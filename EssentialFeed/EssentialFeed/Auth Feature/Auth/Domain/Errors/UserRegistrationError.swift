import Foundation

public enum UserRegistrationError: Error, Equatable {
    case connectivity
    case invalidData
    case emailAlreadyInUse
    case replayAttackDetected
    case abuseDetected
    case tokenStorageFailed
    case credentialsSaveFailed
    case unknown
}
