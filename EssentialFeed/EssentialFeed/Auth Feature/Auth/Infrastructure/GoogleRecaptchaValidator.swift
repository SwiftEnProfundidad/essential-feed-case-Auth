import Foundation

public final class GoogleRecaptchaValidator: CaptchaValidator {
    private let secretKey: String
    private let httpClient: HTTPClient
    private let verifyURL: URL

    public init(
        secretKey: String, httpClient: HTTPClient,
        verifyURL: URL = URL(string: "https://www.google.com/recaptcha/api/siteverify")!
    ) {
        self.secretKey = secretKey
        self.httpClient = httpClient
        self.verifyURL = verifyURL
    }

    public func validateCaptcha(response token: String, clientIP: String?) async throws
        -> CaptchaValidationResult
    {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "secret", value: self.secretKey),
            URLQueryItem(name: "response", value: token)
        ]

        if let clientIP {
            components.queryItems?.append(URLQueryItem(name: "remoteip", value: clientIP))
        }

        guard let bodyData = components.query?.data(using: .utf8) else {
            throw CaptchaError.malformedRequest
        }

        var request = URLRequest(url: verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, httpResponse) = try await httpClient.send(request)

            guard httpResponse.statusCode == 200 else {
                throw CaptchaError.serviceUnavailable
            }

            let recaptchaResponse = try JSONDecoder().decode(RecaptchaResponse.self, from: data)

            return CaptchaValidationResult(
                isValid: recaptchaResponse.success,
                score: recaptchaResponse.score,
                challengeId: recaptchaResponse.challengeTs,
                timestamp: Date()
            )
        } catch let specificError as CaptchaError {
            throw specificError
        } catch _ as DecodingError {
            throw CaptchaError.invalidResponse
        } catch {
            throw CaptchaError.unknownError(error.localizedDescription)
        }
    }
}

private struct RecaptchaResponse: Codable {
    let success: Bool
    let score: Double?
    let action: String?
    let challengeTs: String?
    let hostname: String?
    let errorCodes: [String]?

    enum CodingKeys: String, CodingKey {
        case success
        case score
        case action
        case challengeTs = "challenge_ts"
        case hostname
        case errorCodes = "error-codes"
    }
}
