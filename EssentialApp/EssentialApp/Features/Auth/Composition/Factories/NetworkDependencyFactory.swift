@preconcurrency import EssentialFeed
import Foundation

enum NetworkDependencyFactory {
    static func makeHTTPClient() -> HTTPClient {
        URLSessionHTTPClient(session: URLSession(configuration: .ephemeral))
    }

    static func makeLoginAPI(httpClient: HTTPClient) -> UserLoginAPI {
        HTTPUserLoginAPI(client: httpClient)
    }
}
