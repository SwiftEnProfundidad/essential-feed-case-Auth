import Foundation

public struct CaptchaValidationResult: Equatable {
    public let isValid: Bool
    public let score: Double?
    public let challengeId: String?
    public let timestamp: Date

    public init(isValid: Bool, score: Double? = nil, challengeId: String? = nil, timestamp: Date = Date()) {
        self.isValid = isValid
        self.score = score
        self.challengeId = challengeId
        self.timestamp = timestamp
    }
}
