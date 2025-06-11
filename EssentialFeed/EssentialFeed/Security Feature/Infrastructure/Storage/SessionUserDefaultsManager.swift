import Foundation

public final class SessionUserDefaultsManager: SessionUserDefaultsCleaning {
    private let userDefaults: UserDefaults
    private let sessionKeys: [String]

    public init(userDefaults: UserDefaults = .standard, sessionKeys: [String]? = nil) {
        self.userDefaults = userDefaults
        self.sessionKeys = sessionKeys ?? SessionUserDefaultsManager.defaultSessionKeys
    }

    public func clearSessionData() async throws {
        for key in sessionKeys {
            userDefaults.removeObject(forKey: key)
        }
    }

    private static let defaultSessionKeys = [
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
