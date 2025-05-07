//
// SwiftInDepth. -05/05/2025.
//

import Foundation

public protocol TokenProvider {
	var currentToken: String? { get set }
}

public final class APIInterceptor: HTTPClient {
	private let decoratee: HTTPClient
	private var tokenProvider: TokenProvider
	private let refreshTokenUseCase: RefreshTokenUseCase
	
	public init(
		decoratee: HTTPClient,
		tokenProvider: TokenProvider,
		refreshTokenUseCase: RefreshTokenUseCase
	) {
		self.decoratee = decoratee
		self.tokenProvider = tokenProvider
		self.refreshTokenUseCase = refreshTokenUseCase
	}
	
	public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
		var authenticatedRequest = request
		if let token = tokenProvider.currentToken {
			authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		
		do {
			return try await decoratee.send(authenticatedRequest)
		} catch {
			if isUnauthorized(error) {
				let newToken = try await refreshTokenUseCase.execute()
				tokenProvider.currentToken = newToken.value
				var retriedRequest = request
				retriedRequest.setValue("Bearer \(newToken.value)", forHTTPHeaderField: "Authorization")
				return try await decoratee.send(retriedRequest)
			}
			throw error
		}
	}
	
	private func isUnauthorized(_ error: Error) -> Bool {
		// Implementa la lógica real según tu error HTTPClient
		if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
			return true
		}
		// Si tienes un error custom, comprueba el statusCode == 401
		return false
	}
}

public final class InMemoryTokenProvider: TokenProvider {
	public var currentToken: String?
	public init(token: String? = nil) {
		self.currentToken = token
	}
}
