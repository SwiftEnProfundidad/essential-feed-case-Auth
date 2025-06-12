import Foundation

public protocol HTTPClientAuthenticationHandler {
    func handle(_ request: URLRequest, with client: HTTPClient) async throws -> (Data, HTTPURLResponse)
}
