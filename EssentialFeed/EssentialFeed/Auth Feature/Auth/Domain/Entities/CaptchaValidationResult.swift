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

public enum BotDetectionResult: Equatable {
    case human
    case suspicious(reason: String)
    case bot(confidence: Double)
}

public enum RequestPattern: Equatable {
    case passwordRecovery
    case login
    case registration
}

public enum SecurityEvent: Equatable {
    case botDetected(confidence: Double)
    case suspiciousActivity(reason: String)
    case captchaFailed
    case lowCaptchaScore(score: Double)
    case captchaError(error: String)
    case captchaRequired
}
