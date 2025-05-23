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

        let requestedURLs = await httpClient.requestedURLs
        let lastHTTPBody = await httpClient.lastHTTPBody

        XCTAssertEqual(requestedURLs, [URL(string: "https://test-register-endpoint.com")!], "Should send request to correct registration endpoint")
        XCTAssertEqual(lastHTTPBody, [
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
        let notifierSpy = UserRegistrationNotifierSpy()
        let validatorStub = RegistrationValidatorTestStub()

        let sut = UserRegistrationUseCase(
            persistenceService: persistenceSpy,
            validator: validatorStub,
            httpClient: httpClient,
            registrationEndpoint: URL(string: "https://test-register-endpoint.com")!,
            notifier: notifierSpy
        )
        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(persistenceSpy, file: file, line: line)
        trackForMemoryLeaks(notifierSpy, file: file, line: line)
        // trackForMemoryLeaks(validatorStub, file: file, line: line)
        return (sut, httpClient, persistenceSpy, notifierSpy)
    }
}

struct TestError: Error { let id: String }
