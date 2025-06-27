import EssentialFeed
import Foundation

public final class HardcodedCaptchaValidator: CaptchaValidator {
    public init() {}

    public func validateCaptcha(response token: String, clientIP _: String?) async throws -> CaptchaValidationResult {
        // ADD: Small delay to simulate network request
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // CHANGE: Always return success for demo purposes
        // In real implementation, this would validate with Google reCAPTCHA servers
        print("✅ CAPTCHA validated successfully (demo mode): \(token)")

        return CaptchaValidationResult(
            isValid: true,
            score: 0.9,
            challengeId: "demo-challenge-\(UUID().uuidString.prefix(8))",
            timestamp: Date()
        )
    }
}
