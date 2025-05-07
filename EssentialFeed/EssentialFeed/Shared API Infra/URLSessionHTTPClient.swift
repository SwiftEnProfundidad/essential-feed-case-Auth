//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import Foundation

public final class URLSessionHTTPClient: HTTPClient {
	private let session: URLSession
	
	public init(session: URLSession = .shared) {
		self.session = session
	}
	
	public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
		let (data, response) = try await session.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw URLError(.badServerResponse)
		}
		// Si data es nil, devolvemos Data vacía
		return (data, httpResponse)
	}
}
