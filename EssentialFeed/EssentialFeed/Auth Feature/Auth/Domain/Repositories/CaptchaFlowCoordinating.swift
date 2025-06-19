import Foundation

public protocol CaptchaFlowCoordinating {
    func shouldTriggerCaptcha(failedAttempts: Int) -> Bool
    func handleCaptchaValidation(token: String, username: String) async -> Result<Void, CaptchaError>
}
