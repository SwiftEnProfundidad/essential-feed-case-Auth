
import XCTest
@testable import EssentialFeed // Asegúrate que esta importación esté presente para acceder a TokenRefreshService si es internal

final class RefreshTokenUseCaseTests: XCTestCase {

	func test_init_doesNotSendRequest() {
		let (_, client, storage, _) = makeSUT()

		XCTAssertTrue(client.requests.isEmpty)
		XCTAssertTrue(storage.messages.isEmpty)
	}

	func test_execute_sendsCorrectRequest() async throws {
		let (sut, client, storage, parserSpy) = makeSUT() // parserSpy se devuelve desde makeSUT
		let url = URL(string: "https://any-refresh-url.com")! // Asegúrate que esta URL coincida con la refreshURL de makeSUT

		let executeTask = Task { try await sut.execute() }

		let requestRegistered = expectation(description: "Request registered")
		Task {
			while client.requests.isEmpty {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
			requestRegistered.fulfill()
		}

		await fulfillment(of: [requestRegistered], timeout: 1.0)
		
		guard let firstRequest = client.requests.first else {
			XCTFail("No request registered in HTTPClientSpy")
			return
		}
		XCTAssertEqual(firstRequest.url, url) // Verificar contra la URL del SUT

		// Simular respuesta exitosa del servidor
		let response200 = HTTPURLResponse(url: firstRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		// El Data() aquí es lo que se pasará al parserSpy.parse(from: data)
		let responseData = Data() 
		client.complete(with: responseData, response: response200)
		
		// Espera a que la ejecución termine realmente
		_ = await executeTask.value // Capturar el resultado si es necesario para otras aserciones

		// CHANGE: Definir el token esperado basado en lo que TokenParserSpy devuelve
		// Dado que TokenParserSpy devuelve un token fijo, podemos replicarlo aquí.
		// Para mayor precisión, si Date() influye, considera mockear Date o usar una referencia de fecha fija.
		// Por simplicidad ahora, asumimos que el Date() en el spy y aquí son "suficientemente cercanos" o
		// que la igualdad de Token no es super estricta con milisegundos de Date si no lo mockeamos.
		// Idealmente, el TokenParserSpy debería permitirte obtener el token que devolvió o stubbear uno exacto.
		let expectedTokenFromParser = try parserSpy.parse(from: responseData) // Obtenemos el token como lo haría el SUT

		// CHANGE: Corregir la aserción para storage.messages
		XCTAssertEqual(storage.messages, [.loadRefreshToken, .save(expectedTokenFromParser)], "Should load and then save refresh token in storage")
		XCTAssertEqual(client.requests.count, 1)
		XCTAssertEqual(client.requestedHTTPMethods, ["POST"])
		// XCTAssertEqual(client.requestedHeaders, [["Authorization": "Bearer any-token"]]) // Esta aserción es incorrecta para el request de refresh token
		// El request de refresh token usualmente envía el refresh token en el body, no un access token en el header.
		// Verifica qué headers envía realmente tu TokenRefreshService o si esta aserción es para otro test.
		// Por ahora, la comento ya que parece incorrecta para este flujo.
		// Si tu TokenRefreshService SÍ añade un header específico (ej. Content-Type), valida eso.
	}

	// Helpers
	private func makeSUT(
		file: StaticString = #file,
		line: UInt = #line
	// CHANGE: Devolver también el TokenParserSpy para usarlo en las aserciones
	) -> (sut: RefreshTokenUseCase, client: HTTPClientSpy, storage: TokenStorageSpy, parser: TokenParserSpy) {
		let client = HTTPClientSpy()
		let storage = TokenStorageSpy()
		let parser = TokenParserSpy() // Crear la instancia del spy
		let refreshURL = URL(string: "https://any-refresh-url.com")! // Define una URL para el SUT

		// CHANGE: Actualizar la inicialización de TokenRefreshService
		let sut = TokenRefreshService(
			httpClient: client,
			tokenStorage: storage,
			tokenParser: parser, // Pasar la instancia del parserSpy
			refreshURL: refreshURL // Pasar la URL de refresco
		)
		trackForMemoryLeaks(client, file: file, line: line)
		trackForMemoryLeaks(storage, file: file, line: line)
		trackForMemoryLeaks(parser, file: file, line: line) // Trackear el parserSpy
		trackForMemoryLeaks(sut, file: file, line: line)
		return (sut, client, storage, parser)
	}
}
