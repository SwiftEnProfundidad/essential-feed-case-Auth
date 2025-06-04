import Foundation

public final class InterceptorChain: HTTPClient, @unchecked Sendable {
    private let interceptors: [HTTPClientInterceptor]
    private let baseClient: HTTPClient

    public init(interceptors: [HTTPClientInterceptor], baseClient: HTTPClient) {
        self.interceptors = interceptors
        self.baseClient = baseClient
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard !interceptors.isEmpty else {
            return try await baseClient.send(request)
        }

        return try await executeChain(request: request, interceptorIndex: 0)
    }

    private func executeChain(request: URLRequest, interceptorIndex: Int) async throws -> (Data, HTTPURLResponse) {
        guard interceptorIndex < interceptors.count else {
            return try await baseClient.send(request)
        }

        let currentInterceptor = interceptors[interceptorIndex]
        let nextClient = NextHTTPClient { nextRequest in
            try await self.executeChain(request: nextRequest, interceptorIndex: interceptorIndex + 1)
        }

        return try await currentInterceptor.intercept(request, next: nextClient)
    }
}

private final class NextHTTPClient: HTTPClient, @unchecked Sendable {
    private let handler: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await handler(request)
    }
}
