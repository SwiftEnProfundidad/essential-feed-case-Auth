import EssentialFeed
import XCTest

final class SessionUserDefaultsManagerIntegrationTests: XCTestCase {
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        userDefaults = UserDefaults.standard
        clearDefaultSessionKeysFromUserDefaults()
    }

    override func tearDownWithError() throws {
        clearDefaultSessionKeysFromUserDefaults()
        userDefaults = nil
        try super.tearDownWithError()
    }

    func test_clearSessionData_removesDefaultSessionKeysFromUserDefaults() async throws {
        let sut = SessionUserDefaultsManager(userDefaults: userDefaults)
        let defaultKeys = SessionUserDefaultsManager.defaultSessionKeys

        for key in defaultKeys {
            userDefaults.set("test_value_for_\(key)", forKey: key)
            XCTAssertNotNil(userDefaults.string(forKey: key), "UserDefaults should have value for key '\(key)' before clearing.")
        }

        try await sut.clearSessionData()

        for key in defaultKeys {
            XCTAssertNil(userDefaults.object(forKey: key), "UserDefaults should be nil for key '\(key)' after clearing.")
        }
    }

    func test_clearSessionData_withCustomKeys_removesOnlyCustomKeysFromUserDefaults() async throws {
        let customKeys = ["custom_key_1", "custom_key_2", "another_key_to_keep"]
        let keysToClear = [customKeys[0], customKeys[1]]
        let keyToKeep = customKeys[2]

        let sut = SessionUserDefaultsManager(userDefaults: userDefaults, sessionKeys: keysToClear)

        userDefaults.set("value1", forKey: keysToClear[0])
        userDefaults.set("value2", forKey: keysToClear[1])
        userDefaults.set("valueToKeep", forKey: keyToKeep)

        XCTAssertNotNil(userDefaults.string(forKey: keysToClear[0]), "UserDefaults should have value for '\(keysToClear[0])' before clearing.")
        XCTAssertNotNil(userDefaults.string(forKey: keysToClear[1]), "UserDefaults should have value for '\(keysToClear[1])' before clearing.")
        XCTAssertNotNil(userDefaults.string(forKey: keyToKeep), "UserDefaults should have value for '\(keyToKeep)' before clearing.")

        try await sut.clearSessionData()

        XCTAssertNil(userDefaults.object(forKey: keysToClear[0]), "UserDefaults should be nil for key '\(keysToClear[0])' after clearing.")
        XCTAssertNil(userDefaults.object(forKey: keysToClear[1]), "UserDefaults should be nil for key '\(keysToClear[1])' after clearing.")
        XCTAssertNotNil(userDefaults.object(forKey: keyToKeep), "UserDefaults should still have value for key '\(keyToKeep)' as it was not in sessionKeys for SUT.")
    }

    func test_clearSessionData_whenNoKeysArePresent_completesWithoutError() async throws {
        let sut = SessionUserDefaultsManager(userDefaults: userDefaults)
        clearDefaultSessionKeysFromUserDefaults()
        try await sut.clearSessionData()
    }

    private func clearDefaultSessionKeysFromUserDefaults() {
        for key in SessionUserDefaultsManager.defaultSessionKeys {
            userDefaults.removeObject(forKey: key)
        }
    }
}

extension SessionUserDefaultsManager {
    static var defaultSessionKeys: [String] {
        [
            "user_id",
            "username",
            "last_login_date",
            "session_expires_at",
            "user_preferences_cache",
            "biometric_enabled",
            "auto_login_enabled",
            "session_token_cache",
            "user_profile_cache"
        ]
    }
}
