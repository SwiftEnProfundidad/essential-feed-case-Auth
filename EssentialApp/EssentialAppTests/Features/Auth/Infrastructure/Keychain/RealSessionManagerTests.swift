import XCTest
import EssentialApp

final class RealSessionManagerTests: XCTestCase {
    func test_isAuthenticated_queriesKeychainWithAuthTokenKey() {
        let spy = KeychainHelperSpy()
        let sut = makeSUT(keychain: spy)
        _ = sut.isAuthenticated
        XCTAssertEqual(spy.getCalls, ["auth_token"])
    }
    
    func test_isAuthenticated_returnsTrueWhenKeychainHasToken() {
        let spy = KeychainHelperSpy()
        spy.stubbedValue = "any_token"
        let sut = makeSUT(keychain: spy)
        XCTAssertTrue(sut.isAuthenticated)
    }
    
    func test_isAuthenticated_returnsFalseWhenKeychainHasNoToken() {
        let spy = KeychainHelperSpy()
        spy.stubbedValue = nil
        let sut = makeSUT(keychain: spy)
        XCTAssertFalse(sut.isAuthenticated)
    }

    // MARK: - Helpers
    private func makeSUT(keychain: KeychainStore, file: StaticString = #file, line: UInt = #line) -> RealSessionManager {
        let sut = RealSessionManager(keychain: keychain)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
}
