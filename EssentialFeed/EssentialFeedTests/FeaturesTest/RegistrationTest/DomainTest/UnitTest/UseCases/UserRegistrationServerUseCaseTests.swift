import XCTest
import EssentialFeed
import Foundation

// CU: Registro de Usuario en servidor
// Checklist: Validar integración de registro con servidor y manejo de respuestas

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
	) -> (sut: UserRegistrationUseCase, httpClient: RegistrationHTTPClientSpy) {
		let httpClient = RegistrationHTTPClientSpy()
		let tokenStorage = TokenStorageSpy()
		let keychain = KeychainFullSpy()
		let offlineStore = OfflineRegistrationStoreSpy()
		
		let sut = UserRegistrationUseCase(
			keychain: keychain,
			tokenStorage: tokenStorage,
			offlineStore: offlineStore,
			validator: RegistrationValidatorTestStub(),
			httpClient: httpClient,
			registrationEndpoint: URL(string: "https://test-register-endpoint.com")!
		)
		trackForMemoryLeaks(httpClient, file: file, line: line)
		trackForMemoryLeaks(sut, file: file, line: line)
		trackForMemoryLeaks(tokenStorage, file: file, line: line)
		trackForMemoryLeaks(keychain, file: file, line: line)
		trackForMemoryLeaks(offlineStore, file: file, line: line)
		return (sut, httpClient)
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
	
	// Helpers para tests
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
