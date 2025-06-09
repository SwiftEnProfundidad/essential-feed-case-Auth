import EssentialFeed
import Foundation

public final class ReplayAttackProtectorSpy: ReplayAttackProtector {
    public var stubbedProtectedRequest = URLRequest(url: URL(string: "https://protected.example.com")!)
    public var stubbedError: Error?
    public private(set) var protectRequestCallCount = 0
    public private(set) var receivedRequest: URLRequest?

    public init() {}

    public func protectRequest(_ request: URLRequest) async throws -> URLRequest {
        protectRequestCallCount += 1
        receivedRequest = request

        if let error = stubbedError {
            throw error
        }

        return stubbedProtectedRequest
    }
}
