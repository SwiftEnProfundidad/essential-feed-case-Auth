import Foundation

public enum RegistrationError: Error {
    case missingRequest
    case missingProtectedRequest
    case missingHTTPResponse
    case missingTokenAndUser
    case incompleteExecution
}
