import EssentialFeed
import Foundation

class UserDefaultsLoginPersistence: LoginPersistence {
    private let userDefaults: UserDefaults
    private let tokenKey = "AuthToken"
    private let refreshTokenKey = "AuthRefreshToken"
    private let tokenExpiryKey = "AuthTokenExpiry"
    private let offlineCredentialsKey = "OfflineLoginCredentials"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveToken(_ token: Token) {
        print("Persistence: Saving token \(token.accessToken) and refresh token \(token.refreshToken ?? "nil") and expiry \(token.expiry)")
        userDefaults.set(token.accessToken, forKey: tokenKey)
        userDefaults.set(token.refreshToken, forKey: refreshTokenKey)
        userDefaults.set(token.expiry.timeIntervalSince1970, forKey: tokenExpiryKey)
    }

    func getToken() -> Token? {
        guard let accessToken = userDefaults.string(forKey: tokenKey),
              let expiryTimestamp = userDefaults.object(forKey: tokenExpiryKey) as? TimeInterval
        else {
            return nil
        }
        let refreshToken = userDefaults.string(forKey: refreshTokenKey)
        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)

        print("Persistence: Retrieving token \(accessToken), refresh token \(refreshToken ?? "nil"), and expiry \(expiryDate)")
        return Token(accessToken: accessToken, expiry: expiryDate, refreshToken: refreshToken)
    }

    func clearToken() {
        print("Persistence: Clearing token")
        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
        userDefaults.removeObject(forKey: tokenExpiryKey)
    }

    func saveOfflineCredentials(_ credentials: LoginCredentials) {
        // En una app real, esto debería estar encriptado
        print("Persistence: Saving offline credentials for \(credentials.email)")
        if let encoded = try? JSONEncoder().encode(credentials) {
            userDefaults.set(encoded, forKey: offlineCredentialsKey)
        }
    }

    func getOfflineCredentials() -> LoginCredentials? {
        guard let savedData = userDefaults.data(forKey: offlineCredentialsKey),
              let decoded = try? JSONDecoder().decode(LoginCredentials.self, from: savedData)
        else {
            return nil
        }
        print("Persistence: Retrieving offline credentials for \(decoded.email)")
        return decoded
    }

    func clearOfflineCredentials() {
        print("Persistence: Clearing offline credentials")
        userDefaults.removeObject(forKey: offlineCredentialsKey)
    }
}
