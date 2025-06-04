import Foundation

public protocol HTTPClientInterceptor {
    func intercept(_ request: URLRequest, next: HTTPClient) async throws -> (Data, HTTPURLResponse)
}
