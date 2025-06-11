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
}
