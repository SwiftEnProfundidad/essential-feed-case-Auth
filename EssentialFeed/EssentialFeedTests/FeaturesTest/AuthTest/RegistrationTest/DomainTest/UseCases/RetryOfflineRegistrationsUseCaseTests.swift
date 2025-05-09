
import XCTest
import EssentialFeed

final class RetryOfflineRegistrationsUseCaseTests: XCTestCase {
	
	func test_execute_whenNoOfflineRegistrations_doesNotAttemptApiCallAndCompletesSuccessfully() async {
		let (sut, spies) = makeSUT()
		spies.offlineStore.completeLoadAll(with: [])
		
		let results = await sut.execute()
		
		XCTAssertTrue(results.isEmpty, "Expected no results when no offline registrations")
		XCTAssertEqual(spies.offlineStore.messages, [.loadAll], "Expected only one call to loadAll")
		XCTAssertTrue(spies.authAPI.registrationRequests.isEmpty, "Expected no API registration calls")
		XCTAssertTrue(spies.tokenStorage.messages.isEmpty, "Expected no token storage calls")
	}
	
	func test_execute_whenOneOfflineRegistrationExists_AndApiCallSucceeds_savesTokenAndDeletesFromOfflineStore() async {
		let (sut, spies) = makeSUT()
		
		let offlineData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "ValidPassword123!")
		spies.offlineStore.completeLoadAll(with: [offlineData])
		
		let expectedApiResponse = UserRegistrationResponse(userID: "user-123", token: "new-auth-token", refreshToken: "new-refresh-token")
		spies.authAPI.completeRegistrationSuccessfully(with: expectedApiResponse)
		spies.tokenStorage.completeSaveSuccessfully()
		spies.offlineStore.completeDeletionSuccessfully() // Necesita existir en el OfflineRegistrationStoreSpy compartido
		
		let results = await sut.execute()
		
		XCTAssertEqual(results.count, 1, "Expected one result for one offline registration")
		guard let firstResult = results.first else {
			XCTFail("Results array should not be empty")
			return
		}
		
		switch firstResult {
			case .success:
				break
			case .failure(let error):
				XCTFail("Expected success, but got error: \(error)")
				return
		}
		
		XCTAssertEqual(spies.offlineStore.messages, [.loadAll, .delete(offlineData)], "Expected loadAll then delete from offlineStore")
		XCTAssertEqual(spies.authAPI.registrationRequests.count, 1, "Expected one call to authAPI.register")
		XCTAssertEqual(spies.authAPI.registrationRequests.first, offlineData, "AuthAPI was called with correct data")
		
		XCTAssertEqual(spies.tokenStorage.messages.count, 1, "Expected one call to tokenStorage.save")
		if let firstTokenMessage = spies.tokenStorage.messages.first {
			if case .save(let savedToken) = firstTokenMessage {
				XCTAssertEqual(savedToken.value, expectedApiResponse.token, "Saved token value mismatch")
			} else {
				XCTFail("Expected .save message in tokenStorage, got \(firstTokenMessage)")
			}
		}
	}
	
	func test_execute_whenApiCallFails_keepsDataAndReturnsRegistrationFailed() async {
		let (sut, spies) = makeSUT()
		
		let offlineData = UserRegistrationData(name: "Bob", email: "bob@mail.com", password: "ValidPassword123!")
		spies.offlineStore.completeLoadAll(with: [offlineData])
		
		let expectedError = UserRegistrationError.emailAlreadyInUse
		spies.authAPI.completeRegistration(with: expectedError)
		
		let results = await sut.execute()
		
		XCTAssertEqual(results.count, 1)
		if case let .failure(.registrationFailed(receivedError))? = results.first {
			XCTAssertEqual(receivedError, expectedError)
		} else {
			XCTFail("Expected .registrationFailed error")
		}
		
		XCTAssertEqual(spies.offlineStore.messages, [.loadAll], "Should call loadAll only, without delete")
		XCTAssertEqual(spies.tokenStorage.messages.count, 0, "Should not attempt to save token")
		XCTAssertEqual(spies.authAPI.registrationRequests, [offlineData], "API should receive the registration")
	}
	
	// MARK: - whenTokenStorageFails
	
	func test_execute_whenTokenStorageFails_keepsDataAndReturnsTokenStorageFailed() async {
		let (sut, spies) = makeSUT()
		
		let offlineData = UserRegistrationData(name: "Ana", email: "ana@mail.com", password: "ValidPassword!1")
		spies.offlineStore.completeLoadAll(with: [offlineData])
		
		let apiResponse = UserRegistrationResponse(userID: "user-ana", token: "token-ana", refreshToken: "refresh-ana")
		spies.authAPI.completeRegistrationSuccessfully(with: apiResponse)
		
		struct DummyError: Swift.Error {}
		spies.tokenStorage.completeSave(withError: DummyError())
		
		let results = await sut.execute()
		
		XCTAssertEqual(results.count, 1)
		if case let .failure(.tokenStorageFailed(receivedError)) = results.first {
			XCTAssertTrue(receivedError is DummyError, "Expected underlying DummyError, got \(receivedError)")
		} else {
			XCTFail("Expected .tokenStorageFailed with DummyError")
		}
		
		XCTAssertEqual(spies.offlineStore.messages, [.loadAll], "Solo loadAll, sin delete")
	}
	
	// MARK: - whenDeleteFails
	
	func test_execute_whenDeleteFails_keepsDataAndReturnsOfflineStoreDeleteFailed() async {
		let (sut, spies) = makeSUT()
		
		let offlineData = UserRegistrationData(name: "Eve", email: "eve@mail.com", password: "StrongPassw0rd!")
		spies.offlineStore.completeLoadAll(with: [offlineData])
		
		let apiResponse = UserRegistrationResponse(userID: "user-eve", token: "token-eve", refreshToken: "refresh-eve")
		spies.authAPI.completeRegistrationSuccessfully(with: apiResponse)
		spies.tokenStorage.completeSaveSuccessfully()
		
		struct DummyError: Swift.Error {}
		spies.offlineStore.completeDeletion(with: DummyError())
		
		let results = await sut.execute()
		
		XCTAssertEqual(results.count, 1)
		
		if case let .failure(.offlineStoreDeleteFailed(receivedError)) = results.first {
			XCTAssertTrue(receivedError is DummyError, "Expected DummyError")
		} else {
			XCTFail("Expected .offlineStoreDeleteFailed")
		}
		
		XCTAssertEqual(spies.offlineStore.messages, [.loadAll, .delete(offlineData)])
		XCTAssertEqual(spies.tokenStorage.messages.count, 1)
	}
	
	// MARK: Helpers
	
	private struct Spies {
		let offlineStore: OfflineRegistrationStoreSpy // Este será el spy compartido
		let authAPI: AuthAPISpy
		let tokenStorage: TokenStorageSpy
	}
	
	private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: RetryOfflineRegistrationsUseCase, spies: Spies) {
		let offlineStoreSpy = OfflineRegistrationStoreSpy()
		let authAPISpy = AuthAPISpy()
		let tokenStorageSpy = TokenStorageSpy()
		
		// El caso de uso ahora exige ambos protocolos (login + registration),
		// AuthAPISpy los conforma, así que lo usamos dos veces.
		let sut = RetryOfflineRegistrationsUseCase(
			offlineStore: offlineStoreSpy,
			authAPI: authAPISpy,
			tokenStorage: tokenStorageSpy,
			userRegistration: authAPISpy
		)
		
		trackForMemoryLeaks(sut, file: file, line: line)
		trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
		trackForMemoryLeaks(authAPISpy, file: file, line: line)
		trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
		
		return (sut, Spies(offlineStore: offlineStoreSpy, authAPI: authAPISpy, tokenStorage: tokenStorageSpy))
	}
}
