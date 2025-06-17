import Foundation

public final class HTTPPasswordRecoveryAPI: PasswordRecoveryAPI {
    private let httpClient: HTTPClient
    private let baseURL: URL

    public init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func recover(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        Task {
            do {
                let url = baseURL.appendingPathComponent("auth/password-recovery")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let requestBody = ["email": email]
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                let (data, response) = try await httpClient.send(request)

                switch response.statusCode {
                case 200:
                    let apiResponse = try JSONDecoder().decode(PasswordRecoveryAPIResponse.self, from: data)
                    let result = PasswordRecoveryResponse(message: apiResponse.message, resetToken: apiResponse.resetToken)
                    completion(.success(result))
                case 404:
                    completion(.failure(.emailNotFound))
                case 429:
                    let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init) ?? 300
                    completion(.failure(.rateLimitExceeded(retryAfterSeconds: retryAfter)))
                case 400 ... 499:
                    completion(.failure(.invalidEmailFormat))
                case 500 ... 599:
                    completion(.failure(.unknown))
                default:
                    completion(.failure(.network))
                }
            } catch {
                completion(.failure(.network))
            }
        }
    }
}

private struct PasswordRecoveryAPIResponse: Codable {
    let message: String
    let resetToken: String?

    enum CodingKeys: String, CodingKey {
        case message
        case resetToken = "reset_token"
    }
}
