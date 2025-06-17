import EssentialFeed
import Foundation

public final class PasswordRecoveryAPISpy: PasswordRecoveryAPI {
    public var stubbedResult: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .success(PasswordRecoveryResponse(message: "OK"))
    public var recoverCallCount = 0

    public init() {}

    public func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        recoverCallCount += 1
        completion(stubbedResult)
    }
}
