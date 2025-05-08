
import XCTest
import EssentialFeed // Asegúrate que este sea el nombre correcto de tu módulo de dominio

class UserRegistrationUseCaseIntegrationTests: XCTestCase {

    func test_register_withSuccessfulServerResponse_savesTokenAndCredentials() async throws {
        // Arrange
        let uniqueUser = UserRegistrationData.makeUnique()
        let expectedToken = Token.make()
        // Usamos la estructura ServerAuthResponse directamente para el payload,
        // ya que es la que UserRegistrationUseCase espera decodificar.
        let serverResponsePayload = ServerAuthResponse(
            user: .init(name: uniqueUser.name, email: uniqueUser.email),
            token: .init(value: expectedToken.value, expiry: expectedToken.expiry)
        )
        let encoder = JSONEncoder()
        encoder.dateDecodingStrategy = .iso8601
        let serverResponseData = try encoder.encode(serverResponsePayload)
        
        // Asumimos que HTTPClientStub está disponible y tiene un helper para esto
        let httpClientStub = HTTPClientStub.stubForSuccessfulResponse(data: serverResponseData, statusCode: 201)
        
        let tokenStorageSpy = TokenStorageSpy()
        let keychainSpy = KeychainFullSpy() 
        let offlineStoreSpy = OfflineRegistrationStoreSpy() // Definido abajo
        let notifierSpy = UserRegistrationNotifierSpy()     // Definido abajo
        let validator = RegistrationValidatorAlwaysValid()  // Definido abajo
        
        let sut = UserRegistrationUseCase(
            keychain: keychainSpy,
            tokenStorage: tokenStorageSpy,
            offlineStore: offlineStoreSpy,
            validator: validator,
            httpClient: httpClientStub,
            registrationEndpoint: URL(string: "https://any-url.com")!,
            notifier: notifierSpy
        )
        
        trackForMemoryLeaks(sut, file: #file, line: #line)
        trackForMemoryLeaks(httpClientStub, file: #file, line: #line)
        trackForMemoryLeaks(tokenStorageSpy, file: #file, line: #line)
        trackForMemoryLeaks(keychainSpy, file: #file, line: #line)
        trackForMemoryLeaks(offlineStoreSpy, file: #file, line: #line)
        trackForMemoryLeaks(notifierSpy, file: #file, line: #line)
        // trackForMemoryLeaks(validator) // Si es una clase

        // Act
        let result = await sut.register(
            name: uniqueUser.name, 
            email: uniqueUser.email, 
            password: uniqueUser.password
        )

        // Assert
        switch result {
        case .success(let registeredUser):
            XCTAssertEqual(registeredUser.name, uniqueUser.name)
            XCTAssertEqual(registeredUser.email, uniqueUser.email)
            
            XCTAssertEqual(tokenStorageSpy.messages.count, 1)
            if case let .save(savedToken) = tokenStorageSpy.messages.first {
                XCTAssertEqual(savedToken.value, expectedToken.value)
                XCTAssertEqual(savedToken.expiry, expectedToken.expiry, accuracy: 1.0) 
            } else {
                XCTFail("Expected token to be saved, got \(String(describing: tokenStorageSpy.messages.first))")
            }
            
            XCTAssertEqual(keychainSpy.saveSpy.saveCallCount, 1)
            XCTAssertEqual(keychainSpy.saveSpy.lastKey, uniqueUser.email)
            XCTAssertEqual(keychainSpy.saveSpy.lastData, uniqueUser.password.data(using: .utf8))
            
            XCTAssertTrue(offlineStoreSpy.messages.isEmpty)
            XCTAssertTrue(notifierSpy.receivedErrors.isEmpty, "Expected no errors to be notified on success")

        case .failure(let error):
            XCTFail("Expected successful registration, got \(error) instead")
        }
    }

    // TODO: test_register_withNoConnectivity_savesToOfflineStore_andNotifies()
    // Este test verificará la integración con un HTTPClientStub que simula no conectividad,
    // el OfflineRegistrationStoreSpy y el UserRegistrationNotifierSpy.
}

// MARK: - Helpers & Local Spies/Stubs

// Definición interna de ServerAuthResponse para el encoder, debe coincidir con la de UserRegistrationUseCase
private struct ServerAuthResponse: Codable {
    struct UserPayload: Codable {
        let name: String
        let email: String
    }
    struct TokenPayload: Codable {
        let value: String
        let expiry: Date
    }
    let user: UserPayload
    let token: TokenPayload
}

private extension UserRegistrationData {
    static func makeUnique(id: UUID = UUID()) -> UserRegistrationData {
        UserRegistrationData(name: "User \(id.uuidString.prefix(8))", email: "user-\(id.uuidString.prefix(8))@example.com", password: "Password\(id.uuidString.prefix(8))")
    }
}

private extension Token {
    static func make(value: String = "test-token-\(UUID().uuidString)", expiryInterval: TimeInterval = 3600) -> Token {
        Token(value: value, expiry: Date().addingTimeInterval(expiryInterval))
    }
}

// Spy para OfflineRegistrationStore (similar al de UserRegistrationUseCaseTests)
private final class OfflineRegistrationStoreSpy: OfflineRegistrationStore {
    enum Message: Equatable {
        case save(UserRegistrationData)
    }
    private(set) var messages = [Message]()
    var saveError: Error?
    
    func save(_ data: UserRegistrationData) async throws {
        if let error = saveError { throw error }
        messages.append(.save(data))
    }
}

// Spy para UserRegistrationNotifier (similar al de UserRegistrationUseCaseTests)
private final class UserRegistrationNotifierSpy: UserRegistrationNotifier {
    private(set) var receivedErrors = [Error]()
    // Puedes añadir propiedades computadas si las necesitas para aserciones específicas
    // var notifiedEmailInUse: Bool { receivedErrors.contains { ($0 as? UserRegistrationError) == .emailAlreadyInUse } }
    // var notifiedConnectivityError: Bool { receivedErrors.contains { ($0 as? NetworkError) == .noConnectivity } }
    
    func notifyRegistrationFailed(with error: Error) {
        receivedErrors.append(error)
    }
}

// Stub para RegistrationValidator (similar al de UserRegistrationUseCaseTests)
private final class RegistrationValidatorAlwaysValid: RegistrationValidatorProtocol {
    func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
        return nil // Siempre válido para estos tests de integración
    }
}

// Placeholder para HTTPClientStub - Deberás asegurarte que esto está disponible
// Si HTTPClientStub.swift de EssentialAppTests es tu referencia:
// Necesitarás un helper como `stubForSuccessfulResponse` o similar.
// class HTTPClientStub: HTTPClient { ... } // Definición completa o importación necesaria

// Ejemplo de cómo podría ser un helper en tu HTTPClientStub:
/*
extension HTTPClientStub {
    static func stubForSuccessfulResponse(data: Data, statusCode: Int, url: URL = URL(string: "https://any-url.com")!) -> HTTPClientStub {
        HTTPClientStub { _ in
            .success((data, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!))
        }
    }

    static func stubForError(_ error: Error) -> HTTPClientStub {
        HTTPClientStub { _ in .failure(error) }
    }
}
*/

