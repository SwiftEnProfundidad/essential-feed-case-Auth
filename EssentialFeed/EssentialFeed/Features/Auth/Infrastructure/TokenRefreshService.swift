import Foundation
import EssentialFeed // Asegúrate de que Token y TokenStorage son accesibles desde este target

final class TokenStorageSpy: TokenStorage {
	// Mensajes para registrar las llamadas y sus parámetros
	enum Message: Equatable {
		case loadRefreshToken
		case save(Token) // Token ya es Equatable
	}
	private(set) var messages = [Message]()
	
	// Stubs para controlar el comportamiento del Spy
	var loadRefreshTokenStub: Result<String?, Error>?
	var saveTokenError: Error?
	
	// Implementación del protocolo TokenStorage
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
		// Si no hay stub, puedes decidir un comportamiento por defecto.
		// Por ejemplo, devolver un token de prueba o nil.
		// Aquí devuelvo nil como un comportamiento por defecto razonable si no se especifica.
		// O podrías lanzar un error si un test espera que siempre se configure un stub.
		// return "default-spy-refresh-token" 
		return nil // O un valor por defecto más explícito para los tests si es necesario
	}
	
	func save(_ token: Token) async throws {
		messages.append(.save(token))
		
		if let error = saveTokenError {
			throw error
		}
		// Si no hay error, la operación de guardado se considera exitosa en el Spy.
	}
}
