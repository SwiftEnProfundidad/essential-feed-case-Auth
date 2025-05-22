import Foundation

public final class EssentialFeedBundleMarker {}

public protocol LoginBlockMessageProvider {
    func message(forAttempts attempts: Int, maxAttempts: Int) -> String
    func message(for error: Error) -> String
}

public struct DefaultLoginBlockMessageProvider: LoginBlockMessageProvider {
    public init() {}

    public func message(forAttempts _: Int, maxAttempts _: Int) -> String {
        NSLocalizedString("error_login_accountLocked_attempts", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Account locked due to multiple failed attempts (specific).")
    }

    public func message(for error: Error) -> String {
        if let errorWithMessage = error as? LoginErrorType {
            return errorWithMessage.errorMessage()
        }
        if let loginError = error as? LoginError {
            switch loginError {
            case .invalidCredentials:
                return NSLocalizedString("error_login_invalidCredentials", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Invalid username or password.")
            case .invalidEmailFormat:
                return NSLocalizedString("error_login_invalidEmailFormat", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Email format is incorrect.")
            case .invalidPasswordFormat:
                return NSLocalizedString("error_login_invalidPasswordFormat", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Password format is incorrect (e.g., empty).")
            case .network:
                return NSLocalizedString("error_login_network", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Network connection issue.")
            case .unknown:
                return NSLocalizedString("error_login_unknown", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: An unspecified error occurred.")
            case .tokenStorageFailed:
                return NSLocalizedString("error_login_tokenStorageFailed", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Failed to store authentication token.")
            case .noConnectivity:
                return NSLocalizedString("error_login_noConnectivity", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: No internet connectivity.")
            case .offlineStoreFailed:
                return NSLocalizedString("error_login_offlineStoreFailed", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Failed to store data offline.")
            case .accountLocked:
                return NSLocalizedString("error_login_accountLocked", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Account locked after too many attempts (general).")
            case .messageForMaxAttemptsReached:
                return NSLocalizedString("error_login_maxAttemptsReached", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Login error: Maximum login attempts reached.")
            }
        }
        return NSLocalizedString("error_login_generic", tableName: nil, bundle: Bundle(for: EssentialFeedBundleMarker.self), comment: "Generic login error message.")
    }
}
