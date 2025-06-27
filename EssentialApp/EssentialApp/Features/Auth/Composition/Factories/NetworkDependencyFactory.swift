@preconcurrency import EssentialFeed
import Foundation

enum NetworkDependencyFactory {
    static func makeHTTPClient() -> HTTPClient {
        URLSessionHTTPClient(session: URLSession(configuration: .ephemeral))
    }

    static func makeLoginAPI(httpClient: HTTPClient) -> UserLoginAPI {
        HTTPUserLoginAPI(client: httpClient)
    }

    static func makeTokenStorage() -> TokenStorage {
        // ⚠️ TEMPORAL: Using InMemoryTokenStorage for demo/testing
        // TODO: PRODUCTION - Revert to Keychain for security:
        // return KeychainDependencyFactory.makeTokenStorage()
        //
        // Current setup is for demo purposes only.
        // In production, tokens MUST be stored in Keychain for security.
        #if DEBUG
            return InMemoryTokenStorage()
        #else
            // PRODUCTION: Use secure Keychain storage
            return KeychainDependencyFactory.makeTokenStorage()
        #endif
    }

    static func makeCaptchaValidator(httpClient: HTTPClient) -> CaptchaValidator {
        #if DEBUG
            return HardcodedCaptchaValidator()
        #else
            // PRODUCTION: Use real Google reCAPTCHA
            let config = ConfigurationFactory.makeUserLoginConfiguration()
            return GoogleRecaptchaValidator(
                secretKey: config.captchaSecretKey,
                httpClient: httpClient
            )
        #endif
    }
}
