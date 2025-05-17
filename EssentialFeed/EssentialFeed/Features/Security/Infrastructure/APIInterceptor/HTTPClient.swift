
import Foundation

public protocol HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public extension HTTPClient {
    @available(*, deprecated, message: "Migrar a send(_:) async")
    func get(from url: URL) async throws -> (Data, HTTPURLResponse) {
        try await send(URLRequest(url: url))
    }
}
