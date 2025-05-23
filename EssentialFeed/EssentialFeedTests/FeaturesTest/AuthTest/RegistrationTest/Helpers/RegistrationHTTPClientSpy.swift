import EssentialFeed
import Foundation

actor RegistrationHTTPClientSpy: HTTPClient {
    private var _requests = [URLRequest]()

    var requests: [URLRequest] {
        _requests
    }

    var requestedURLs: [URL] {
        _requests.compactMap(\.url)
    }

    var lastHTTPBody: [String: String]? {
        guard let lastRequest = _requests.last,
              let body = lastRequest.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: String]
        else { return nil }
        return json
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        _requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        return (Data(), response)
    }

    func complete(with _: Data, response: HTTPURLResponse) async {
        _ = try? await send(URLRequest(url: response.url!))
    }

    func complete(with _: Error) async {
        _ = try? await send(URLRequest(url: URL(string: "https://test-endpoint.com")!))
    }
}
