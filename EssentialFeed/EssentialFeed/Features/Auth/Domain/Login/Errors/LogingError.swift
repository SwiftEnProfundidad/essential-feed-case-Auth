
import Foundation

public enum LoginError: Error, Equatable {
    case invalidCredentials
    case invalidEmailFormat
    case invalidPasswordFormat
    case network
    case tokenStorageFailed
    case noConnectivity
    case unknown
    case offlineStoreFailed
}
