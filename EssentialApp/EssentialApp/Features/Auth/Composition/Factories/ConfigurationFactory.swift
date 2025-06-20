@preconcurrency import EssentialFeed
import Foundation

enum ConfigurationFactory {
    static func makeUserLoginConfiguration() -> UserLoginConfiguration {
        let captchaSecretKey =
            ProcessInfo.processInfo.environment["CAPTCHA_SECRET_KEY"]
                ?? "YOUR_FALLBACK_CAPTCHA_SECRET_KEY"

        return UserLoginConfiguration(
            maxFailedAttempts: 3,
            lockoutDuration: 300,
            tokenDuration: 3600,
            captchaSecretKey: captchaSecretKey
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
