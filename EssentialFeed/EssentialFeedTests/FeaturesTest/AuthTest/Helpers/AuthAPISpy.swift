
import EssentialFeed
import Foundation
import XCTest

public final class AuthAPISpy: UserLoginAPI, UserRegistrationAPI {
    var stubbedResult: Result<LoginResponse, LoginError>?
    private(set) var wasCalled = false

    public private(set) var registrationRequests = [UserRegistrationData]()
    public var registrationResult: Result<UserRegistrationResponse, UserRegistrationError>?

    public func login(with _: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        wasCalled = true
        guard let result = stubbedResult else {
            XCTFail("API should NOT be called for invalid input. Provide a stubbedResult only when expected.")
            return .failure(.invalidCredentials)
        }
        return result
    }

    public func register(with data: UserRegistrationData) async -> Result<UserRegistrationResponse, UserRegistrationError> {
        registrationRequests.append(data)
        return registrationResult ?? .failure(.unknown)
    }

    public func completeRegistrationSuccessfully(with response: UserRegistrationResponse) {
        registrationResult = .success(response)
    }

    func completeRegistration(with error: UserRegistrationError) {
        registrationResult = .failure(error)
    }
}
