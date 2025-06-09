import Foundation

public final class DefaultReplayAttackProtector: ReplayAttackProtector {
    private let nonceGenerator: NonceGenerator
    private let timestampProvider: TimestampProvider
    private let requestSigner: RequestSigner

    public init(
        nonceGenerator: NonceGenerator,
        timestampProvider: TimestampProvider,
        requestSigner: RequestSigner
    ) {
        self.nonceGenerator = nonceGenerator
        self.timestampProvider = timestampProvider
        self.requestSigner = requestSigner
    }

    public func protectRequest(_ request: URLRequest) async throws -> URLRequest {
        let nonce = nonceGenerator.generateNonce()
        let timestamp = timestampProvider.currentTimestamp()

        return try await requestSigner.signRequest(request, with: nonce, timestamp: timestamp)
    }
}
