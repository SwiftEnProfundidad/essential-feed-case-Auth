import Foundation

public protocol NonceGenerator {
    func generateNonce() -> String
}

public protocol TimestampProvider {
    func currentTimestamp() -> Int64
}

public protocol RequestSigner {
    func signRequest(_ request: URLRequest, with nonce: String, timestamp: Int64) async throws -> URLRequest
}

public protocol ReplayAttackProtector {
    func protectRequest(_ request: URLRequest) async throws -> URLRequest
}
