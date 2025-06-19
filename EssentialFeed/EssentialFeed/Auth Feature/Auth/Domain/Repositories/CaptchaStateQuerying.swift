import Foundation

public protocol CaptchaStateQuerying {
    var shouldShowCaptcha: Bool { get }
    var captchaToken: String? { get }
}
