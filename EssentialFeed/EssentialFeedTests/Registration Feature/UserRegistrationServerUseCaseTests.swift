import XCTest
import EssentialFeed
import Foundation
// CU: Registro de Usuario en servidor
// Checklist: Validar integración de registro con servidor y manejo de respuestas
import Foundation

final class UserRegistrationServerUseCaseTests: XCTestCase {

func test_registerUser_sendsRequestToServer() async throws {
        let name = "Carlos"
        let email = "carlos@email.com"
        let password = "StrongPassword123"
        let (sut, httpClient) = makeSUT()

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
    ) -> (sut: UserRegistrationUseCase, httpClient: HTTPClientSpy) {
        let httpClient = HTTPClientSpy()
        let sut = UserRegistrationUseCase(
            keychain: makeKeychainFullSpy(),
            validator: RegistrationValidatorStub(),
            httpClient: httpClient,
            registrationEndpoint: URL(string: "https://test-register-endpoint.com")!
        )
        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, httpClient)
    }
}

// MARK: - Test Doubles

final class HTTPClientSpy: HTTPClient {
    private(set) var requestedURLs: [URL] = []
    private(set) var lastHTTPBody: [String: String]? = nil

    func post(to url: URL, body: [String: String], completion: @escaping (HTTPClient.Result) -> Void) -> HTTPClientTask {
        requestedURLs.append(url)
        lastHTTPBody = body
        // Simula una respuesta exitosa con la tupla correcta
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        completion(.success((Data(), response)))
        return DummyHTTPClientTask()
    }

    // Implementación dummy para cumplir el protocolo
    func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> HTTPClientTask {
        return DummyHTTPClientTask()
    }
}

final class DummyHTTPClientTask: HTTPClientTask {
    func cancel() {}
}
