import EssentialFeed
import XCTest

final class RealSessionManagerTests: XCTestCase {
    func test_isAuthenticated_queriesKeychainWithAuthTokenKey() {
        let (sut, keychainSpy) = makeSUT()

        _ = sut.isAuthenticated

        XCTAssertEqual(keychainSpy.getDataCalls, ["auth_token"])
    }

    func test_isAuthenticated_returnsTrueWhenKeychainHasToken() {
        let (sut, keychainSpy) = makeSUT()
        keychainSpy.stubbedData = "any_token".data(using: .utf8)

        XCTAssertTrue(sut.isAuthenticated)
    }

    func test_isAuthenticated_returnsFalseWhenKeychainHasNoToken() {
        let (sut, keychainSpy) = makeSUT()
        keychainSpy.stubbedData = nil

        XCTAssertFalse(sut.isAuthenticated)
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #file,
        line: UInt = #line
    ) -> (sut: KeychainSessionManager, keychainSpy: KeychainHelperSpy) {
        let keychainSpy = KeychainHelperSpy()
        let sut = KeychainSessionManager(keychain: keychainSpy)

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(keychainSpy, file: file, line: line)

        return (sut, keychainSpy)
    }
}
