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
        KeychainDependencyFactory.makeTokenStorage()
    }

    static func makeCaptchaValidator(httpClient: HTTPClient) -> CaptchaValidator {
        let config = ConfigurationFactory.makeUserLoginConfiguration()
        return GoogleRecaptchaValidator(
            secretKey: config.captchaSecretKey,
            httpClient: httpClient
        )
    }
}
