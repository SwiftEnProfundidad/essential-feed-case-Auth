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
        let (sut, httpClient, _, _, replayProtector) = makeSUT()

        _ = await sut.register(name: name, email: email, password: password)

        _ = await httpClient.requestedURLs
        let requests = await httpClient.requests

        XCTAssertEqual(replayProtector.protectRequestCallCount, 1, "Should protect request against replay attacks")
        XCTAssertEqual(requests.count, 1, "Should send one request to server")

        guard let lastRequest = requests.last else {
            XCTFail("Should have at least one request")
            return
        }

        guard let httpBody = lastRequest.httpBody else {
            XCTFail("Request should have HTTP body with registration data")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] else {
            XCTFail("HTTP body should contain valid JSON data")
            return
        }

        XCTAssertEqual(json["name"] as? String, name, "Should include correct name in request body")
        XCTAssertEqual(json["email"] as? String, email, "Should include correct email in request body")
        XCTAssertEqual(json["password"] as? String, password, "Should include correct password in request body")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (sut: UserRegistrationUseCase, httpClient: RegistrationHTTPClientSpy, persistenceSpy: RegistrationPersistenceSpy, notifierSpy: UserRegistrationNotifierSpy, replayProtector: ReplayAttackProtectorSpy) {
        let httpClient = RegistrationHTTPClientSpy()
        let persistenceSpy = RegistrationPersistenceSpy()
        let notifierSpy = UserRegistrationNotifierSpy()
        let validatorStub = RegistrationValidatorTestStub()
        let replayProtector = ReplayAttackProtectorSpy()
        let responseMapper = UserRegistrationResponseMapper(notifier: notifierSpy)
        let registrationPersistenceService = DefaultRegistrationPersistenceService(tokenStorage: persistenceSpy, credentialsStore: persistenceSpy, offlineStore: persistenceSpy)
        let offlineHandler = DefaultOfflineRegistrationHandler(offlineStore: persistenceSpy, notifier: notifierSpy)

        let commands: [RegistrationCommand] = [
            ValidationCommand(validator: validatorStub, notifier: notifierSpy),
            RequestCreationCommand(registrationEndpoint: URL(string: "https://test-register-endpoint.com")!),
            ReplayProtectionCommand(replayProtector: replayProtector),
            HTTPRequestCommand(httpClient: httpClient),
            ResponseMappingCommand(responseMapper: responseMapper),
            PersistenceCommand(persistenceService: registrationPersistenceService)
        ]

        let registrationService = RegistrationCommandChain(commands: commands, offlineHandler: offlineHandler, notifier: notifierSpy)
        let sut = UserRegistrationUseCase(registrationService: registrationService)

        trackForMemoryLeaks(httpClient, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(persistenceSpy, file: file, line: line)
        trackForMemoryLeaks(notifierSpy, file: file, line: line)

        return (sut, httpClient, persistenceSpy, notifierSpy, replayProtector)
    }
}

struct TestError: Error { let id: String }
