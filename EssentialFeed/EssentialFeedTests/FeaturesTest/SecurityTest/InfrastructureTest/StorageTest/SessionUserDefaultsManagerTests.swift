import EssentialFeed
import XCTest

final class SessionUserDefaultsManagerTests: XCTestCase {
    func test_clearSessionData_removesAllSessionKeys() async throws {
        let userDefaults = UserDefaults(suiteName: "test_suite")!
        let sessionKeys = ["key1", "key2", "key3"]
        let sut = SessionUserDefaultsManager(userDefaults: userDefaults, sessionKeys: sessionKeys)

        // Set some test data
        userDefaults.set("value1", forKey: "key1")
        userDefaults.set("value2", forKey: "key2")
        userDefaults.set("value3", forKey: "key3")
        userDefaults.set("should_remain", forKey: "non_session_key")

        try await sut.clearSessionData()

        XCTAssertNil(userDefaults.object(forKey: "key1"), "Should remove session key1")
        XCTAssertNil(userDefaults.object(forKey: "key2"), "Should remove session key2")
        XCTAssertNil(userDefaults.object(forKey: "key3"), "Should remove session key3")
        XCTAssertEqual(userDefaults.string(forKey: "non_session_key"), "should_remain", "Should not remove non-session keys")

        // Cleanup
        userDefaults.removePersistentDomain(forName: "test_suite")
    }

    func test_clearSessionData_withDefaultKeys_removesExpectedSessionData() async throws {
        let userDefaults = UserDefaults(suiteName: "test_suite_default")!
        let sut = SessionUserDefaultsManager(userDefaults: userDefaults)

        // Set some default session data
        userDefaults.set("user123", forKey: "user_id")
        userDefaults.set("john_doe", forKey: "username")
        userDefaults.set(Date(), forKey: "last_login_date")
        userDefaults.set("some_other_data", forKey: "app_version")

        try await sut.clearSessionData()

        XCTAssertNil(userDefaults.object(forKey: "user_id"), "Should remove user_id")
        XCTAssertNil(userDefaults.object(forKey: "username"), "Should remove username")
        XCTAssertNil(userDefaults.object(forKey: "last_login_date"), "Should remove last_login_date")
        XCTAssertEqual(userDefaults.string(forKey: "app_version"), "some_other_data", "Should not remove non-session data")

        // Cleanup
        userDefaults.removePersistentDomain(forName: "test_suite_default")
    }
}
