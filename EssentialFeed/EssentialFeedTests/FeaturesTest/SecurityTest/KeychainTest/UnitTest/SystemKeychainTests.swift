import EssentialFeed
import XCTest

final class SystemKeychainTests: XCTestCase {
    // Checklist: Thread Safety
    // CU: SystemKeychain-save-concurrent
    func test_save_isThreadSafe_underConcurrentAccess() {
        var sut: SystemKeychain? = makeSUT()
        let key: String = uniqueKey()
        let data = "concurrent-data".data(using: .utf8)!
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let expectation = expectation(description: "Concurrent saves")
        expectation.expectedFulfillmentCount = 10
        let resultsLock = NSLock()
        var results = [KeychainSaveResult]()

        let dispatchGroup = DispatchGroup()

        for _ in 0 ..< 10 {
            dispatchGroup.enter()
            queue.async { [weak sut] in
                guard let strongSut = sut else {
                    resultsLock.lock()
                    results.append(.failure)
                    resultsLock.unlock()
                    expectation.fulfill()
                    dispatchGroup.leave()
                    return
                }
                // Ahora usamos strongSut
                let result: KeychainSaveResult = strongSut.save(data: data, forKey: key)
                resultsLock.lock()
                results.append(result)
                resultsLock.unlock()
                expectation.fulfill()
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()
        sut = nil

        wait(for: [expectation], timeout: 15.0)
        XCTAssertTrue(results.allSatisfy { $0 == .success || $0 == .duplicateItem }, "All concurrent saves should succeed or be duplicateItem. Results: \(results)")
    }

    // Checklist: Validation after Save
    // CU: SystemKeychain-save-validationAfterSave
    func test_save_returnsFailure_whenValidationAfterSaveFails_dueToCorruption() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .success
        let data: Data = "expected".data(using: .utf8)!
        let key: String = uniqueKey()
        spy.willValidateAfterSave = { receivedKey in
            spy.simulateCorruption(forKey: receivedKey)
        }
        let result: KeychainSaveResult = sut.save(data: data, forKey: key)
        XCTAssertEqual(result, .failure, "Save should return failure if validation after save fails due to corruption")
    }

    // Checklist: Duplicate Item and Update Fails
    // CU: SystemKeychain-save-duplicateItem
    func test_save_returnsDuplicateItem_whenUpdateFailsAfterDuplicate() {
        let (sut, spy) = makeSpySUT()
        let data: Data = "data".data(using: .utf8)!
        let key: String = uniqueKey()
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecDuplicateItem
        let result: KeychainSaveResult = sut.save(data: data, forKey: key)
        XCTAssertEqual(result, .duplicateItem, "Should return duplicateItem when update fails after duplicate")
    }

    // Checklist: Error Fallback
    // CU: SystemKeychain-save-noFallback
    func test_save_onNoFallbackStrategy_alwaysReturnsFailure() {
        let sut: NoFallback = makeNoFallback()
        let data: Data = "irrelevant".data(using: .utf8)!
        let key: String = uniqueKey()
        let result: KeychainSaveResult = sut.save(data: data, forKey: key)
        XCTAssertEqual(result, .failure, "NoFallback should always return failure on save")
    }

    func test_save_returnsFailure_forEmptyKeyOrData() {
        let sut: SystemKeychain = makeSUT()
        let data: Data = "irrelevant".data(using: .utf8)!
        XCTAssertEqual(sut.save(data: data, forKey: ""), .failure, "Saving with empty key should fail")
        XCTAssertEqual(sut.save(data: Data(), forKey: uniqueKey()), .failure, "Saving with empty data should fail")
    }

    func test_save_supportsUnicodeKeys_andLargeBinaryData_withRealKeychain() {
        let sut: SystemKeychain = makeSUT()
        let unicodeKey = "🔑-ключ-密钥-llave-\(UUID().uuidString)"
        let data = Data((0 ..< 10000).map { _ in UInt8.random(in: 0 ... 255) })

        let result = sut.save(data: data, forKey: unicodeKey)
        XCTAssertEqual(result, .success, "Should save large binary data with unicode key successfully")

        let loaded: Data? = sut.load(forKey: unicodeKey)
        XCTAssertEqual(loaded, data, "Loaded data should match saved data for unicode key")

        _ = sut.delete(forKey: unicodeKey)
    }

    func test_save_and_delete_withEdgeCaseKeys_andHelpers() {
        let (sut, _) = makeSpySUT()
        let emptyKey = ""
        let spacesKey = "   "
        let normalData: Data = "data".data(using: .utf8)!
        XCTAssertEqual(sut.save(data: normalData, forKey: emptyKey), .failure, "Should fail to save with empty key")
        XCTAssertEqual(sut.save(data: normalData, forKey: spacesKey), .failure, "Should fail to save with spaces key")
        XCTAssertFalse(sut.delete(forKey: emptyKey), "Should fail to delete with empty key")
        XCTAssertFalse(sut.delete(forKey: spacesKey), "Should fail to delete with spaces key")
    }

    func test_delete_returnsTrue_whenKeyDoesNotExist() {
        let (sut, spy) = makeSpySUT()
        let key: String = uniqueKey()
        spy.deleteResultToReturn = true
        XCTAssertTrue(sut.delete(forKey: key), "Should return true when deleting non-existent key (Keychain semantics)")
        XCTAssertEqual(spy.receivedDeleteKey, key)
    }

    // Checklist: Delegates to injected keychain and returns its result
    // CU: SystemKeychain-save-delegation
    func test_save_delegatesToKeychainProtocol_andReturnsSpyResult() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .success
        let data: Data = "data".data(using: .utf8)!
        let key = "spy-key"
        let result: KeychainSaveResult = sut.save(data: data, forKey: key)

        XCTAssertTrue(spy.saveCalled, "Should call save on spy")
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data)
        XCTAssertEqual(spy.receivedSaveKey, key)
        XCTAssertEqual(result, .success, "Should return the spy's save result")
    }

    // Checklist: Save returns false if injected keychain fails
    // CU: SystemKeychain-save-keychainFailure
    func test_save_returnsDuplicateItem_onKeychainFailure_whenUpdateAlsoFailsWithDuplicate() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecDuplicateItem
        let key = "fail-key"
        let result: KeychainSaveResult = sut.save(data: "irrelevant".data(using: .utf8)!, forKey: key)
        XCTAssertEqual(result, .duplicateItem, "Should return duplicateItem on keychain failure if update also fails similarly")
    }

    // Checklist: Save returns false if post-write validation fails
    // CU: SystemKeychain-save-validationAfterSaveFails
    func test_save_returnsFailure_whenValidationAfterSaveFails() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .success
        let data: Data = "expected".data(using: .utf8)!
        let key = "key"
        spy.willValidateAfterSave = { receivedKey in
            spy.simulateCorruption(forKey: receivedKey)
        }
        let result: KeychainSaveResult = sut.save(data: data, forKey: key)
        XCTAssertEqual(result, .failure, "Save result should be .failure if validation fails")
    }

    // Checklist: Save returns false if delete fails before save (during an update attempt)
    // CU: SystemKeychainProtocolWithDeleteFails
    func test_save_returnsFailure_ifDeleteFailsBeforeSaveOnUpdatePath() {
        let (sut, spy) = makeSpySUT()
        let key = "delete-fails-key"
        let initialData = "initial-data".data(using: .utf8)!
        let newData = "new-data".data(using: .utf8)!

        _ = sut.save(data: initialData, forKey: key)
        spy.saveResultToReturn = .duplicateItem

        spy.deleteResultToReturn = false
        spy.updateStatusToReturn = errSecSuccess

        let result: KeychainSaveResult = sut.save(data: newData, forKey: key)

        XCTAssertEqual(result, .failure, "Save should return .failure if delete fails during update attempt")
        XCTAssertTrue(spy.deleteCalled, "Delete should have been called on the spy")
        XCTAssertEqual(spy.receivedDeleteKey, key)
    }

    // Checklist: Save supports large binary data
    // CU: SystemKeychain-save-largeBinary
    func test_save_supportsLargeBinaryData_withSpy() {
        let (sut, spy) = makeSpySUT()
        let key: String = uniqueKey()
        let data = Data((0 ..< 10000).map { _ in UInt8.random(in: 0 ... 255) })
        spy.saveResultToReturn = .success

        let result: KeychainSaveResult = sut.save(data: data, forKey: key)
        XCTAssertEqual(result, .success, "Save should handle large binary data and return .success")
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data)
        XCTAssertEqual(spy.receivedSaveKey, key)
    }

    // Checklist: Save is thread safe under concurrent access
    // CU: SystemKeychain-save-concurrent (already covered by test_save_isThreadSafe_underConcurrentAccess, this is a duplicate intent using spy)
    func test_save_isThreadSafeUnderConcurrentAccess_withSpy() {
        let spy = KeychainFullSpy() // Spy needs to be thread-safe for this test
        let sut: SystemKeychain = makeSUT(keychain: spy)
        let key: String = uniqueKey()
        let data1: Data = "thread-1".data(using: .utf8)!
        let data2: Data = "thread-2".data(using: .utf8)!
        let exp: XCTestExpectation = expectation(description: "concurrent saves with spy")
        exp.expectedFulfillmentCount = 2

        DispatchQueue.global().async {
            _ = sut.save(data: data1, forKey: key)
            exp.fulfill()
        }
        DispatchQueue.global().async {
            _ = sut.save(data: data2, forKey: key)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertTrue(spy.saveCallCount >= 1, "Save should have been called on the spy at least once")
    }

    // Checklist: Save supports unicode keys
    // CU: SystemKeychain-save-unicodeKey
    func test_save_supportsUnicodeKeys_withSpy() {
        let (sut, spy) = makeSpySUT()
        let key = "🔑-ключ-密钥-llave"
        let data: Data = "unicode-data".data(using: .utf8)!
        spy.saveResultToReturn = .success

        let result: KeychainSaveResult = sut.save(data: data, forKey: key)
        XCTAssertEqual(result, .success, "Save should support unicode keys and return .success")
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data)
        XCTAssertEqual(spy.receivedSaveKey, key)
    }

    // Checklist: Save overwrites previous value (forces update path)
    // CU: SystemKeychain-save-overwriteUpdate
    func test_save_overwritesPreviousValue_forcesUpdatePath_withSpy() {
        let (sut, spy) = makeSpySUT()
        let key: String = uniqueKey()
        let data1: Data = "first".data(using: .utf8)!
        let data2: Data = "second".data(using: .utf8)!

        _ = sut.save(data: data1, forKey: key)
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecSuccess

        let resultInitialSave = sut.save(data: data1, forKey: key)
        XCTAssertEqual(resultInitialSave, .success, "Initial save (which becomes update) should succeed")
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data1)

        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecSuccess
        let result = sut.save(data: data2, forKey: key)
        XCTAssertEqual(result, .success, "Save should handle update and return .success")
        XCTAssertTrue(spy.updateCalled, "Update should have been called on spy")
        XCTAssertEqual(spy.receivedUpdateData, data2)
        XCTAssertEqual(spy.receivedUpdateKey, key)
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data2, "Spy's internal storage should reflect the update")
    }

    // Checklist: Save returns false for empty data
    // CU: SystemKeychain-save-emptyData
    func test_save_returnsFailure_forEmptyData() {
        let sut: SystemKeychain = makeSUT()
        let result: KeychainSaveResult = sut.save(data: Data(), forKey: anyKey())
        XCTAssertEqual(result, .failure, "Saving empty data should fail")
    }

    // Checklist: Save returns false for empty key
    // CU: SystemKeychain-save-emptyKey
    func test_save_returnsFailure_forEmptyKey() {
        let sut: SystemKeychain = makeSUT()
        let result: KeychainSaveResult = sut.save(data: anyData(), forKey: "")
        XCTAssertEqual(result, .failure, "Saving with empty key should fail")
    }

    // Checklist: Save handles very long keys
    // CU: SystemKeychain-save-veryLongKey (Behavior with real keychain can vary)
    func test_save_returnsSuccess_forVeryLongKey_withSpy() {
        let (sut, spy) = makeSpySUT()
        let key = String(repeating: "k", count: 1024)
        spy.saveResultToReturn = .success
        let result: KeychainSaveResult = sut.save(data: anyData(), forKey: key)
        XCTAssertEqual(result, .success, "Result should be .success for very long key with a permissive spy")
    }

    // CU: SystemKeychainProtocolWithDeletePrevious
    // Checklist: test_save_deletesPreviousValueBeforeSavingNewOne (This means on update path)
    func test_save_onUpdatePath_deletesPreviousValueBeforeUpdating() {
        let (sut, spy) = makeSpySUT()
        let key: String = anyKey()
        let initialData: Data = "initial".data(using: .utf8)!
        let newData: Data = anyData()

        _ = sut.save(data: initialData, forKey: key)
        spy.saveResultToReturn = .duplicateItem
        spy.deleteResultToReturn = true
        spy.updateStatusToReturn = errSecSuccess

        _ = sut.save(data: newData, forKey: key)

        XCTAssertTrue(spy.deleteCalled, "Should call delete on spy during update")
        XCTAssertEqual(spy.receivedDeleteKey, key, "Should delete the correct key")
        XCTAssertTrue(spy.updateCalled, "Should call update on spy after delete")
        XCTAssertEqual(spy.receivedUpdateKey, key)
        XCTAssertEqual(spy.receivedUpdateData, newData)
    }

    // CU: SystemKeychain-save-specificKeychainErrors
    // Checklist: test_save_handlesSpecificKeychainErrors_duplicateItem
    func test_save_handlesSpecificKeychainErrors_duplicateItem() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecDuplicateItem
        let result = sut.save(data: anyData(), forKey: anyKey())
        XCTAssertEqual(result, .duplicateItem, "Should return .duplicateItem on duplicate item error if update also reports duplicate")
    }

    func test_save_handlesSpecificKeychainErrors_authFailedOnUpdate() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecAuthFailed

        let result = sut.save(data: anyData(), forKey: anyKey())
        XCTAssertEqual(result, .failure, "Should return .failure on auth failed error during update")
    }

    func test_init_withAndWithoutKeychainParameter_shouldNotCrash() {
        _ = makeSpySUT()
        _ = makeSUT() // Default init
    }

    func test_update_onSystemKeychain_withValidAndInvalidInput_withSpy() {
        let (sut, spy) = makeSpySUT()
        let key: String = uniqueKey()
        let data = "original".data(using: .utf8)!
        let updated = "updated".data(using: .utf8)!

        _ = sut.save(data: data, forKey: key)
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecSuccess

        XCTAssertEqual(sut.save(data: data, forKey: key), .success, "Initial save (which becomes update) should succeed")
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data)

        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecSuccess
        XCTAssertEqual(sut.save(data: updated, forKey: key), .success, "Overwriting save (another update) should succeed")
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], updated, "Spy should have updated data")

        XCTAssertEqual(sut.update(data: data, forKey: ""), errSecParam, "Should return errSecParam for empty key (if SUT exposes update)")
        XCTAssertEqual(sut.update(data: Data(), forKey: key), errSecParam, "Should return errSecParam for empty data (if SUT exposes update)")
    }

    func test__save_onSystemKeychain_validatesInputAndSavesCorrectly_withSpy() {
        let (sut, spy) = makeSpySUT()
        let validKey = uniqueKey()
        let validData = "data".data(using: .utf8)!

        spy.saveResultToReturn = .success
        let resultSuccess = sut.save(data: validData, forKey: validKey)
        XCTAssertEqual(resultSuccess, .success, "Should save data with valid key and data")
        XCTAssertEqual(spy.stubbedLoadDataForKey[validKey], validData)

        let resultEmptyKey = sut.save(data: validData, forKey: "")
        XCTAssertEqual(resultEmptyKey, .failure, "Should fail to save with empty key")

        let resultEmptyData = sut.save(data: Data(), forKey: validKey)
        XCTAssertEqual(resultEmptyData, .failure, "Should fail to save with empty data")
    }

    func test_handleDuplicateItem_returnsDuplicateItem_whenMaxAttemptsReached_withSpy() {
        let (sut, spy) = makeSpySUT()
        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecDuplicateItem
        spy.deleteResultToReturn = true
        spy.maxRetriesForDuplicate = 1

        let data: Data = "data".data(using: .utf8)!
        let key: String = uniqueKey()
        let result: KeychainSaveResult = sut.save(data: data, forKey: key)

        XCTAssertEqual(result, .duplicateItem, "Should return .duplicateItem after max duplicate attempts")
        XCTAssertGreaterThanOrEqual(spy.deleteCallCount, spy.maxRetriesForDuplicate)
        XCTAssertGreaterThanOrEqual(spy.updateCallCount, spy.maxRetriesForDuplicate)
    }

    func test__update_onSystemKeychain_failsWithEmptyKeyOrData_ifExposed() {
        let sut = makeSystemKeychain()
        let validKey = uniqueKey()
        let validData = "data".data(using: .utf8)!

        XCTAssertEqual(sut.update(data: validData, forKey: ""), errSecParam, "Should return errSecParam for empty key")
        XCTAssertEqual(sut.update(data: Data(), forKey: validKey), errSecParam, "Should return errSecParam for empty data")
    }

    func test__delete_onSystemKeychain_returnsTrueOnSuccess_withSpy() {
        let (sut, spy) = makeSpySUT()
        let keySuccess = uniqueKey()

        _ = sut.save(data: "irrelevant".data(using: .utf8)!, forKey: keySuccess)
        spy.deleteResultToReturn = true

        XCTAssertTrue(sut.delete(forKey: keySuccess), "Should return true when deletion succeeds")
        XCTAssertEqual(spy.receivedDeleteKey, keySuccess)
        XCTAssertNil(spy.stubbedLoadDataForKey[keySuccess] ?? nil, "Item should be removed from spy's storage after delete")
    }

    func test_save_returnsSuccess_whenHandleDuplicateItemSucceedsWithUpdateAndValidationSucceeds() {
        let (sut, spy) = makeSpySUT()
        let key: String = uniqueKey()
        let data: Data = "data".data(using: .utf8)!

        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecSuccess
        spy.willValidateAfterSave = nil

        let result: KeychainSaveResult = sut.save(data: data, forKey: key)

        XCTAssertEqual(result, .success, "Should return success if update and validation succeed in handleDuplicateItem")
        XCTAssertTrue(spy.updateCalled)
        XCTAssertEqual(spy.receivedUpdateData, data)
        XCTAssertEqual(spy.stubbedLoadDataForKey[key], data, "Spy storage should contain the updated data")
    }

    func test_save_returnsFailure_whenHandleDuplicateItemSucceedsWithUpdateButValidationFails() {
        let (sut, spy) = makeSpySUT()
        let key: String = uniqueKey()
        let data: Data = "data".data(using: .utf8)!

        spy.saveResultToReturn = .duplicateItem
        spy.updateStatusToReturn = errSecSuccess
        spy.willValidateAfterSave = { receivedKey in
            spy.simulateCorruption(forKey: receivedKey)
        }

        let result: KeychainSaveResult = sut.save(data: data, forKey: key)

        XCTAssertEqual(result, .failure, "Should return .failure if update succeeds but validation fails in handleDuplicateItem")
        XCTAssertTrue(spy.updateCalled)
        XCTAssertNil(spy.stubbedLoadDataForKey[key] ?? nil, "Spy storage should not contain data after simulated corruption")
    }
}

// MARK: - Helpers

private extension SystemKeychainTests {
    func makeSystemKeychain() -> SystemKeychain {
        SystemKeychain()
    }

    func makeNoFallback() -> NoFallback {
        NoFallback()
    }

    func makeSUT(
        keychain: KeychainFull? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) -> SystemKeychain {
        let sut = if let keychain {
            SystemKeychain(keychain: keychain)
        } else {
            SystemKeychain()
        }
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    func makeSpySUT(
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: SystemKeychain, spy: KeychainFullSpy) {
        let spy = KeychainFullSpy()
        let sut = SystemKeychain(keychain: spy)
        trackForMemoryLeaks(spy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, spy)
    }

    func anyData() -> Data {
        "test-data".data(using: .utf8)!
    }

    func anyKey() -> String {
        "test-key"
    }

    func uniqueKey() -> String {
        "test-key-\(UUID().uuidString)"
    }
}
