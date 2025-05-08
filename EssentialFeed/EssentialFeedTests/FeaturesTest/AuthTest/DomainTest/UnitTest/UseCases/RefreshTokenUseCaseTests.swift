// RefreshTokenUseCaseTests.swift

@testable import EssentialFeed
import XCTest

final class RefreshTokenUseCaseTests: XCTestCase {
    func test_init_doesNotSendRequest() {
        let (_, client, storage, _) = makeSUT()

        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertTrue(storage.messages.isEmpty)
    }

    func test_execute_sendsCorrectRequest() async throws {
			let (sut, client, storage, _) = makeSUT() // parserSpy es tu TokenParserSpy
        let refreshURLFromSUT = URL(string: "https://any-refresh-url.com")!

        // **CORRECCIÓN CLAVE**: Configurar TokenStorageSpy para que devuelva un refresh token
        storage.completeLoadRefreshToken(with: "any-valid-refresh-token")

        // El TokenParserSpy que tienes siempre devuelve:
        // Token(value: "any-access-token", expiry: Date().addingTimeInterval(3600))
        // No necesita configuración externa para el valor de retorno si ese es el comportamiento deseado.

        let executeTask = Task { try await sut.execute() }

        let requestRegistered = expectation(description: "Request registered")
        Task {
            var attempts = 0
            let maxAttempts = 100 // Evitar un bucle infinito si algo va muy mal (100 * 10ms = 1s)
            while client.requests.isEmpty && !executeTask.isCancelled && attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms
                attempts += 1
            }
            
            if !client.requests.isEmpty {
                requestRegistered.fulfill()
            } else {
                // Si llegamos aquí, o la tarea se canceló, o se agotaron los intentos,
                // y la request no se registró.
                // No es necesario un XCTFail aquí porque el guard let firstRequest posterior
                // y el await executeTask.value manejarán los fallos.
                // Simplemente cumplimos la expectation para evitar un timeout que enmascare
                // el error real si executeTask ya falló, o para permitir que el guard let falle.
                // Si la request NUNCA se hizo y executeTask NO falló, el guard let fallará.
                requestRegistered.fulfill()
            }
        }

        await fulfillment(of: [requestRegistered], timeout: 1.5) // Aumentamos ligeramente el timeout por si acaso

        guard let firstRequest = client.requests.first else {
            XCTFail("No request registered in HTTPClientSpy. executeTask might have failed before making a network call (e.g., due to an error thrown by sut.execute()).")
            return
        }
        XCTAssertEqual(firstRequest.url, refreshURLFromSUT)
        XCTAssertEqual(firstRequest.httpMethod, "POST")

        // El token que TokenParserSpy.parse(from:) devolverá (según tu implementación)
        let expectedTokenAfterParsing = Token(value: "any-access-token", expiry: Date().addingTimeInterval(3600))

        // Simular respuesta exitosa del HTTPClient
        let responseData = Data()
        let httpOkResponse = HTTPURLResponse(url: firstRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        // Asegúrate de completar la solicitud correcta, usando el índice 0 si es la única.
        client.complete(with: responseData, response: httpOkResponse, at: 0) 

        let receivedToken = try await executeTask.value

        // Verificar que el token recibido es el que TokenParserSpy generó
        // MODIFICADO: Comparamos los objetos Token completos
        XCTAssertEqual(receivedToken, expectedTokenAfterParsing, "El token recibido no coincide con el esperado del parserSpy.")

        // Verificar los mensajes del TokenStorageSpy
        XCTAssertEqual(storage.messages.count, 2, "Se esperaban 2 mensajes en TokenStorageSpy")
        if storage.messages.count == 2 {
            XCTAssertEqual(storage.messages[0], .loadRefreshToken)
            XCTAssertEqual(storage.messages[1], .save(expectedTokenAfterParsing))
        }
        
        XCTAssertEqual(client.requests.count, 1)
    }

    // Helpers
    private func makeSUT(
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: RefreshTokenUseCase, client: HTTPClientSpy, storage: TokenStorageSpy, parser: TokenParserSpy) {
        let client = HTTPClientSpy()
        let storage = TokenStorageSpy()
        let parser = TokenParserSpy()
        let refreshURL = URL(string: "https://any-refresh-url.com")!

        let sut = TokenRefreshService(
            httpClient: client,
            tokenStorage: storage,
            tokenParser: parser,
            refreshURL: refreshURL
        )
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(storage, file: file, line: line)
        trackForMemoryLeaks(parser, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client, storage, parser)
    }
}
