import CryptoKit
import EssentialFeed
import XCTest

final class AES256CryptoKitEncryptorTests: XCTestCase {
    func test_encrypt_decrypt_successfullyRecoversOriginalData() throws {
        let (sut, _) = makeSUT()
        let originalData = "Secret test data".data(using: .utf8)!

        let encryptedData = try sut.encrypt(originalData)
        XCTAssertNotEqual(encryptedData, originalData, "Encrypted data should not be the same as original")

        let decryptedData = try sut.decrypt(encryptedData)
        XCTAssertEqual(decryptedData, originalData, "Decrypted data should match original data")
    }

    func test_decrypt_withDifferentKey_throwsError() throws {
        let (sut, _) = makeSUT() // Original SUT with its key
        let originalData = "Another secret".data(using: .utf8)!
        let encryptedData = try sut.encrypt(originalData) // Encrypt with original key

        let differentKey = SymmetricKey(size: .bits256) // Create a new, different key
        let differentKeySUT = AES256CryptoKitEncryptor(symmetricKey: differentKey) // SUT with the different key

        XCTAssertThrowsError(try differentKeySUT.decrypt(encryptedData)) { error in
            let expectedError = CryptoKitEncryptionError.decryptionFailed(CryptoKitError.authenticationFailure)
            assertCryptoKitError(error as? CryptoKitEncryptionError, matches: expectedError, file: #file, line: #line)
        }
    }

    func test_decrypt_withCorruptedData_throwsError() throws {
        let (sut, _) = makeSUT()
        let originalData = "Sensitive information".data(using: .utf8)!
        var encryptedData = try sut.encrypt(originalData)

        if !encryptedData.isEmpty {
            encryptedData[0] = encryptedData[0] ^ 0x01
        } else {
            XCTFail("Encrypted data is empty, cannot corrupt.")
            return
        }

        XCTAssertThrowsError(try sut.decrypt(encryptedData)) { error in
            let expectedError = CryptoKitEncryptionError.decryptionFailed(CryptoKitError.authenticationFailure)
            assertCryptoKitError(error as? CryptoKitEncryptionError, matches: expectedError, file: #file, line: #line)
        }
    }

    func test_decrypt_withInsufficientData_throwsInvalidSealedBoxDataError() throws {
        let (sut, _) = makeSUT()
        let insufficientData = "short".data(using: .utf8)!

        XCTAssertThrowsError(try sut.decrypt(insufficientData)) { error in
            assertCryptoKitError(error as? CryptoKitEncryptionError, matches: .invalidSealedBoxData, file: #file, line: #line)
        }
    }

    func test_encrypt_producesDifferentCiphertext_forSameData_dueToNonce() throws {
        let (sut, _) = makeSUT()
        let data = "Test data for nonce uniqueness".data(using: .utf8)!

        let encryptedData1 = try sut.encrypt(data)
        let encryptedData2 = try sut.encrypt(data)

        XCTAssertNotEqual(encryptedData1, encryptedData2, "Two encryptions of the same data should produce different ciphertexts due to different nonces")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: AES256CryptoKitEncryptor, key: SymmetricKey) {
        let key = SymmetricKey(size: .bits256)
        let sut = AES256CryptoKitEncryptor(symmetricKey: key)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, key)
    }

    private func compareUnderlyingErrors(_ lhsError: Error?, _ rhsError: Error?, file: StaticString, line: UInt) -> Bool {
        if lhsError == nil, rhsError == nil { return true }
        guard let lhs = lhsError, let rhs = rhsError else {
            XCTFail("Underlying errors do not match: one is nil, the other is not. Expected: \(String(describing: rhsError)), Got: \(String(describing: lhsError))", file: file, line: line)
            return false
        }

        if let lhsCK = lhs as? CryptoKitError, let rhsCK = rhs as? CryptoKitError {
            switch (lhsCK, rhsCK) {
            case (.authenticationFailure, .authenticationFailure):
                return true
            default:
                XCTFail("Underlying CryptoKitErrors do not match or are not a specifically handled pair. Expected: \(String(describing: rhsCK)), Got: \(String(describing: lhsCK))", file: file, line: line)
                return false
            }
        }

        if type(of: lhs) == type(of: rhs) {
            return true
        } else {
            XCTFail("Underlying error types do not match. Expected type: \(type(of: rhs)), Got type: \(type(of: lhs))", file: file, line: line)
            return false
        }
    }

    private func assertCryptoKitError(
        _ receivedError: CryptoKitEncryptionError?,
        matches expectedError: CryptoKitEncryptionError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let receivedError else {
            XCTFail("Received error is nil, but expected \(expectedError)", file: file, line: line)
            return
        }

        switch (receivedError, expectedError) {
        case let (.encryptionFailed(lhsReceived), .encryptionFailed(rhsExpected)):
            if !compareUnderlyingErrors(lhsReceived, rhsExpected, file: file, line: line) {}
        case let (.decryptionFailed(lhsReceived), .decryptionFailed(rhsExpected)):
            if !compareUnderlyingErrors(lhsReceived, rhsExpected, file: file, line: line) {}
        case (.invalidSealedBoxData, .invalidSealedBoxData):
            break
        default:
            XCTFail("CryptoKitEncryptionError cases do not match. Expected: \(expectedError), Got: \(receivedError)", file: file, line: line)
        }
    }
}
