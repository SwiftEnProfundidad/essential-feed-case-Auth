@preconcurrency import EssentialFeed
import Foundation

enum ConfigurationFactory {
    static func makeUserLoginConfiguration() -> UserLoginConfiguration {
        UserLoginConfiguration(
            maxFailedAttempts: 3,
            lockoutDuration: 300,
            tokenDuration: 3600
        )
    }

    public static func makePasswordRecoveryBaseURL() -> URL {
        guard let urlString = ProcessInfo.processInfo.environment["PASSWORD_RECOVERY_BASE_URL"],
              let url = URL(string: urlString)
        else {
            return URL(string: "https://api.essentialapp.com")!
        }
        return url
    }
}
