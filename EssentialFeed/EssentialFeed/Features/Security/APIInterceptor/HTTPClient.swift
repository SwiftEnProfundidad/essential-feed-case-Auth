//
// Copyright © 2025 Essential Developer. All rights reserved.
//

import Foundation

public protocol HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

// Extensión para mantener métodos antiguos (opcional, solo durante transición)
extension HTTPClient {
    @available(*, deprecated, message: "Migrar a send(_:) async")
    public func get(from url: URL) async throws -> (Data, HTTPURLResponse) {
        try await send(URLRequest(url: url))
    }
}
