
import EssentialFeed
import Foundation

public final class HTTPClientDummy: HTTPClient {
    public init() {}
    public func send(_: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw NSError(
            domain: "HTTPClientDummy",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Dummy implementation should not be called in tests"]
        )
    }
}
