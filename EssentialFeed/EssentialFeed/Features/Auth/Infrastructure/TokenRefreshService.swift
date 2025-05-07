import Foundation
// Asegúrate de que Token, TokenStorage, TokenParser y HTTPClient sean accesibles.
// Probablemente necesites: import EssentialFeed o importaciones específicas si están en diferentes módulos/targets.

public final class TokenRefreshService: RefreshTokenUseCase {
	private let httpClient: HTTPClient
	private let tokenStorage: TokenStorage
	private let tokenParser: TokenParser 
	private let refreshURL: URL 
	
	public enum Error: Swift.Error {
		case connectivity
		case invalidData
		case expiredRefreshToken
	}
	
	public init(httpClient: HTTPClient, tokenStorage: TokenStorage, tokenParser: TokenParser, refreshURL: URL) {
		self.httpClient = httpClient
		self.tokenStorage = tokenStorage
		self.tokenParser = tokenParser
		self.refreshURL = refreshURL
	}
	
	public func execute() async throws -> Token {
		guard let refreshToken = try await tokenStorage.loadRefreshToken() else {
			throw Error.expiredRefreshToken
		}
		
		var request = URLRequest(url: refreshURL)
		request.httpMethod = "POST"
		request.httpBody = try JSONEncoder().encode(["refreshToken": refreshToken])
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		do {
			let (data, response) = try await httpClient.send(request) 
			
			guard response.statusCode == 200 else {
				if response.statusCode == 401 {
					throw Error.expiredRefreshToken
				}
				throw Error.invalidData
			}
			
			let newToken = try tokenParser.parse(from: data)
			
			try await tokenStorage.save(newToken)
			
			return newToken
		} catch is Swift.DecodingError {
			throw Error.invalidData
		} catch let error as Error { 
			throw error
		} catch { 
			throw Error.connectivity
		}
	}
}
