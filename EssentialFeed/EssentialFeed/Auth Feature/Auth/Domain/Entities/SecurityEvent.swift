import Foundation

public enum SecurityEvent: Equatable {
    case botDetected(confidence: Double)
    case suspiciousActivity(reason: String)
    case captchaFailed
    case lowCaptchaScore(score: Double)
    case captchaError(error: String)
    case captchaRequired
}
