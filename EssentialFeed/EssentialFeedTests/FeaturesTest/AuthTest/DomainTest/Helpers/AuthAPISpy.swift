//
// Copyright © 2025 Essential Developer. All rights reserved.
//

import EssentialFeed
import Foundation
import XCTest

final class AuthAPISpy: AuthAPI {
    var stubbedResult: Result<LoginResponse, LoginError>?
    private(set) var wasCalled = false

    func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        wasCalled = true
        guard let result = stubbedResult else {
            XCTFail("API should NOT be called for invalid input. Provide a stubbedResult only when expected.")
            return .failure(.invalidCredentials) // Dummy value, test debe fallar antes
        }
        return result
    }
}
