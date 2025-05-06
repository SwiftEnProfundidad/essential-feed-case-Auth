import Foundation

public protocol TokenStorage {
	func loadRefreshToken() throws -> String
	func save(token: Token) throws
}

public protocol TokenParser {
	func parse(from data: Data) throws -> Token
}

public final class TokenRefreshService: RefreshTokenUseCase {
	private let client: HTTPClient
	private let storage: TokenStorage
	private let parser: TokenParser
	
	public init(client: HTTPClient, storage: TokenStorage, parser: TokenParser) {
		self.client = client
		self.storage = storage
		self.parser = parser
	}
	
	public func execute() async throws -> Token {
		let refreshToken = try storage.loadRefreshToken()
		let request = makeRequest(with: refreshToken)
		let (responseData, _) = try await client.send(request)
		let token = try parser.parse(from: responseData) 
		try storage.save(token: token)
		return token
	}
	
	private func makeRequest(with token: String) -> URLRequest {
		var request = URLRequest(url: URL(string: "https://api.essentialdeveloper.com/auth/refresh")!)
		request.httpMethod = "POST"
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		return request
	}
}
