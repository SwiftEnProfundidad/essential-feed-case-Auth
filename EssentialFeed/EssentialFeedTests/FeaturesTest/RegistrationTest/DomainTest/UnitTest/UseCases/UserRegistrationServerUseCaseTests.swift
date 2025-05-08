import EssentialFeed
import Foundation
import XCTest

// CU: Registro de Usuario en servidor
// Checklist: Validar integración de registro con servidor y manejo de respuestas

final class UserRegistrationServerUseCaseTests: XCTestCase {
    func test_registerUser_sendsRequestToServer() async throws {
        let name = "Carlos"
        let email = "carlos@email.com"
        let password = "StrongPassword123"
        let (sut, httpClient, _, _) = makeSUT()

        _ = await sut.register(name: name, email: email, password: password)

        XCTAssertEqual(httpClient.requestedURLs, [URL(string: "https://test-register-endpoint.com")!], "Should send request to correct registration endpoint")
        XCTAssertEqual(httpClient.lastHTTPBody, [
            "name": name,
            "email": email,
            "password": password
        ])
    }

    // MARK: - Helpers
    private func makeSUT(
        file: StaticString = #file, line: UInt = #line
    ) -> (sut: UserRegistrationUseCase, httpClient: RegistrationHTTPClientSpy, persistenceSpy: RegistrationPersistenceSpy, notifierSpy: UserRegistrationNotifierSpy) {
        let httpClient = RegistrationHTTPClientSpy()
        let persistenceSpy = RegistrationPersistenceSpy()
        let notifierSpy = UserRegistrationNotifierSpy() // Asegúrate que este Spy esté definido y sea correcto
        let validatorStub = RegistrationValidatorTestStub() // Asegúrate que este Stub esté definido y sea correcto

        let sut = UserRegistrationUseCase(
            persistence: persistenceSpy,            // Primero persistence
            validator: validatorStub,               // Luego validator
            httpClient: httpClient,                 // Luego httpClient (nombre del parámetro en el init)
            registrationEndpoint: URL(string: "https://test-register-endpoint.com")!,
            notifier: notifierSpy                   // Notifier al final (o según el init)
        )
        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(persistenceSpy, file: file, line: line)
        trackForMemoryLeaks(notifierSpy, file: file, line: line)
        // trackForMemoryLeaks(validatorStub, file: file, line: line) // Si validatorStub es una clase
        return (sut, httpClient, persistenceSpy, notifierSpy)
    }
}

// MARK: - Test Doubles

final class RegistrationHTTPClientSpy: HTTPClient {
    private(set) var requests = [URLRequest]()

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }

    var requestedURLs: [URL] {
        requests.map { $0.url! }
    }

    var lastHTTPBody: [String: String]? {
        guard let lastRequest = requests.last,
              let body = lastRequest.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: String]
        else { return nil }
        return json
    }
}

final class RegistrationPersistenceSpy: RegistrationPersistenceInterfaces {
    // --- Conformance to KeychainProtocol (which is KeychainSavable) ---
    var keychainSaveDataCalls = [(data: Data, key: String)]()
    var keychainSaveResults: [KeychainSaveResult] = []
    func save(data: Data, forKey key: String) -> KeychainSaveResult {
        keychainSaveDataCalls.append((data, key))
        guard !keychainSaveResults.isEmpty else { return .success } // Devuelve .success si no hay nada preconfigurado
        return keychainSaveResults.removeFirst()
    }
    
    var keychainLoadKeyCalls = [String]()
    var keychainLoadDataToReturn: Data?
    func load(forKey key: String) -> Data? {
        keychainLoadKeyCalls.append(key)
        return keychainLoadDataToReturn
    }

    // --- Conformance to TokenStorage ---
    var tokenStorageSaveTokenCalls = [Token]()
    var tokenStorageShouldSaveError = false
    
    func save(_ token: Token) async throws {
        if tokenStorageShouldSaveError { throw TestError(id: "tokenStorageSaveTokenError") }
        tokenStorageSaveTokenCalls.append(token)
    }
    
    var refreshTokenToLoad: String?
    var tokenStorageShouldLoadRefreshTokenThrowError = false
    func loadRefreshToken() async throws -> String? {
        if tokenStorageShouldLoadRefreshTokenThrowError { throw TestError(id: "loadRefreshTokenError") }
        return refreshTokenToLoad
    }

    // --- Conformance to OfflineRegistrationStore ---
    var offlineStoreSaveCalls = [UserRegistrationData]()
    var offlineStoreShouldSaveThrowError = false
    func save(_ data: UserRegistrationData) async throws {
        if offlineStoreShouldSaveThrowError { throw TestError(id: "offlineStoreSaveCallsError") }
        offlineStoreSaveCalls.append(data)
    }

    // --- Métodos Adicionales del Spy (no estrictamente de RegistrationPersistenceInterfaces) ---
    // Mantén estos si tus tests dependen de ellos o si el spy se usa en otros contextos.

    // Para LoginCredentials (si se reutiliza)
    // func save(credentials: LoginCredentials) async throws {}
    // func loadCredentials() async -> LoginCredentials? { nil }
    // func deleteCredentials() async throws {}
    
    // Para KeychainDeletable (si el spy necesita ser más completo que solo KeychainSavable)
    var keychainDeleteKeyCalls = [String]()
    var keychainDeleteResults: [Bool] = []
    func delete(forKey key: String) -> Bool { // Este método NO es parte de KeychainSavable, solo de KeychainFull/Deletable
        keychainDeleteKeyCalls.append(key)
        guard !keychainDeleteResults.isEmpty else { return true } // Devuelve true por defecto si no hay nada preconfigurado
        return keychainDeleteResults.removeFirst()
    }
    
    // Métodos extra para TokenStorage que NO están en el protocolo TokenStorage que me mostraste
    var tokenStorageSaveRefreshTokenCalls = [String?]()
    // func save(refreshToken: String?) async throws { ... }
    
    var tokenToLoad: Token?
    // func loadToken() async -> Token? { return tokenToLoad }
    
    var tokenStorageDeleteTokenCalled = false
    // func deleteToken() async throws { tokenStorageDeleteTokenCalled = true }
    
    var tokenStorageDeleteRefreshTokenCalled = false
    // func deleteRefreshToken() async throws { tokenStorageDeleteRefreshTokenCalled = true }
}

// Asegúrate que UserRegistrationNotifierSpy y RegistrationValidatorTestStub estén definidos y sean correctos.
// struct TestError: Error { let id: String } // Ya lo tienes o está accesible.

struct TestError: Error { let id: String }
