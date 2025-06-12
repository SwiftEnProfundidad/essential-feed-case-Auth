import Foundation

public enum SessionError: Error {
    case tokenRefreshFailed
    case globalLogoutRequired
}
