import Foundation

public protocol CaptchaStateCommanding {
    func setCaptchaRequired(_ required: Bool)
    func setCaptchaToken(_ token: String?)
    func resetCaptchaState()
}
