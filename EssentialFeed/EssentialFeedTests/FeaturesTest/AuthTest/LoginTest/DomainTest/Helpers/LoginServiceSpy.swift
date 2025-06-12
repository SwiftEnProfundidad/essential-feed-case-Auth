import EssentialFeed
import Foundation

public final class LoginServiceSpy: LoginService {
    public private(set) var executeCallCount = 0
    public private(set) var lastCredentials: LoginCredentials?
    public var stubbedResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)

    public init() {}

    public func execute(credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        executeCallCount += 1
        lastCredentials = credentials
        return stubbedResult
    }

    public func completeExecute(with result: Result<LoginResponse, LoginError>) {
        stubbedResult = result
    }

    public func completeExecuteWithSuccess(response: LoginResponse) {
        stubbedResult = .success(response)
    }

    public func completeExecuteWithFailure(error: LoginError) {
        stubbedResult = .failure(error)
    }
}
