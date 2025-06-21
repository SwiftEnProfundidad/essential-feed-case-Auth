import EssentialFeed
import Foundation

final class MockCaptchaValidator: CaptchaValidator {
    private(set) var receivedResponses: [String] = []
    private(set) var receivedClientIPs: [String?] = []
    private(set) var completions: [(Result<CaptchaValidationResult, Error>) -> Void] = []

    var stubbedResult: Result<CaptchaValidationResult, Error>?

    func validateCaptcha(response: String, clientIP: String?) async throws -> CaptchaValidationResult {
        receivedResponses.append(response)
        receivedClientIPs.append(clientIP)

        if let result = stubbedResult {
            switch result {
            case let .success(validationResult):
                return validationResult
            case let .failure(error):
                throw error
            }
        }

        return CaptchaValidationResult(isValid: true)
    }

    func completeWith(result: Result<CaptchaValidationResult, Error>) {
        stubbedResult = result
    }

    func reset() {
        receivedResponses = []
        receivedClientIPs = []
        completions = []
        stubbedResult = nil
    }
}
