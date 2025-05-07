import Foundation
import EssentialFeed

final class TokenStorageSpy: TokenStorage {
	// (save ahora es save(_ token: Token))
	// Si los mensajes solo distinguen entre load y save, podría quedar así
	// o podrías añadir el token al mensaje de save si es relevante para tus tests.
	enum Message: Equatable { // Asegúrate de que Token sea Equatable si lo incluyes aquí
		case loadRefreshToken
		case save(Token) // Asumiendo que Token es Equatable
	}
	private(set) var messages = [Message]()
	
	// Stubs para los valores de retorno y errores
	var loadRefreshTokenStub: Result<String?, Error>?
	var saveTokenError: Error?
	
	func loadRefreshToken() async throws -> String? {
		messages.append(.loadRefreshToken)
		if let stub = loadRefreshTokenStub {
			switch stub {
				case .success(let tokenString):
					return tokenString
				case .failure(let error):
					throw error
			}
		}
		// Valor por defecto si no hay stub
		return "any-stubbed-refresh-token"
	}
	
	func save(_ token: Token) async throws {
		messages.append(.save(token)) // Almacena el token para inspección si es necesario
		if let error = saveTokenError {
			throw error
		}
	}
}
