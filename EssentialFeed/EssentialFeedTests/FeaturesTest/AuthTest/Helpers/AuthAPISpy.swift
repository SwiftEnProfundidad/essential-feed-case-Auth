
import EssentialFeed
import Foundation
import XCTest

public final class AuthAPISpy: UserLoginAPI, UserRegistrationAPI {
    public private(set) var wasCalled = false
    public private(set) var messages: [Message] = []
    public var stubbedResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)

    public struct Message: Equatable {
        public let email: String
        public let password: String
    }

    public private(set) var registrationRequests = [UserRegistrationData]()
    public var registrationResult: Result<UserRegistrationResponse, UserRegistrationError> = .failure(.unknown)

    public func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        wasCalled = true
        messages.append(Message(email: credentials.email, password: credentials.password))
        return stubbedResult
    }

    public func register(with data: UserRegistrationData) async -> Result<UserRegistrationResponse, UserRegistrationError> {
        registrationRequests.append(data)
        return registrationResult
    }

    // MARK: - Helpers

    public func completeRegistrationSuccessfully(with response: UserRegistrationResponse) {
        registrationResult = .success(response)
    }

    public func completeRegistration(with error: UserRegistrationError) {
        registrationResult = .failure(error)
    }

    public func recordAuthentication(email: String, password: String) {
        messages.append(Message(email: email, password: password))
    }
}
