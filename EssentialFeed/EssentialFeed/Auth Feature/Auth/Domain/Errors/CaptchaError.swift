import Foundation

public enum CaptchaError: Error, Equatable {
    case invalidResponse
    case networkError
    case serviceUnavailable
    case rateLimitExceeded
    case malformedRequest
    case unknownError(String)
}
