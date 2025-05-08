// RetryOfflineRegistrationsUseCaseTests.swift
// EssentialFeedTests
//
// Created by Alex on 8/5/2025.

import XCTest
import EssentialFeed

final class RetryOfflineRegistrationsUseCaseTests: XCTestCase {

    func test_execute_whenNoOfflineRegistrations_doesNotAttemptApiCallAndCompletesSuccessfully() async {
        let (sut, spies) = makeSUT() // makeSUT ahora usará el OfflineRegistrationStoreSpy compartido
        spies.offlineStore.completeLoadAll(with: [])

        let results = await sut.execute()

        XCTAssertTrue(results.isEmpty, "Expected no results when no offline registrations")
        XCTAssertEqual(spies.offlineStore.messages, [.loadAll], "Expected only one call to loadAll")
        XCTAssertTrue(spies.authAPI.registrationRequests.isEmpty, "Expected no API registration calls")
        XCTAssertTrue(spies.tokenStorage.messages.isEmpty, "Expected no token storage calls")
    }

    func test_execute_whenOneOfflineRegistrationExists_AndApiCallSucceeds_savesTokenAndDeletesFromOfflineStore() async {
        let (sut, spies) = makeSUT() // makeSUT ahora usará el OfflineRegistrationStoreSpy compartido
        
        let offlineData = UserRegistrationData(name: "Test User", email: "test@example.com", password: "ValidPassword123!")
        spies.offlineStore.completeLoadAll(with: [offlineData])
        
        // Asumimos que UserRegistrationResponse y UserRegistrationError son accesibles
        let expectedApiResponse = UserRegistrationResponse(userID: "user-123", token: "new-auth-token", refreshToken: "new-refresh-token")
        spies.authAPI.completeRegistrationSuccessfully(with: expectedApiResponse) // Necesita existir en AuthAPISpy
        
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
        
        // Esta aserción depende de que el enum Message en el OfflineRegistrationStoreSpy compartido
        // sea Equatable y tenga los casos .loadAll y .delete(UserRegistrationData).
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

    // --- Helpers ---

    private struct Spies {
        let offlineStore: OfflineRegistrationStoreSpy // Este será el spy compartido
        let authAPI: AuthAPISpy 
        let tokenStorage: TokenStorageSpy 
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: RetryOfflineRegistrationsUseCase, spies: Spies) {
        let offlineStoreSpy = OfflineRegistrationStoreSpy() // Conforma a OfflineRegistrationStoreCRUD
        let authAPISpy = AuthAPISpy() 
        let tokenStorageSpy = TokenStorageSpy() 
        
        let sut = RetryOfflineRegistrationsUseCase(
            offlineStore: offlineStoreSpy,
            authAPI: authAPISpy,
            tokenStorage: tokenStorageSpy
        )
        
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(offlineStoreSpy, file: file, line: line)
        trackForMemoryLeaks(authAPISpy, file: file, line: line)
        trackForMemoryLeaks(tokenStorageSpy, file: file, line: line)
        
        return (sut, Spies(offlineStore: offlineStoreSpy, authAPI: authAPISpy, tokenStorage: tokenStorageSpy))
    }
}
