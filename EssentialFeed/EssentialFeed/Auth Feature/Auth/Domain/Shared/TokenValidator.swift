import Foundation

public protocol TokenValidating {
    func isTokenValid(_ token: String) -> Bool
}

public protocol TokenExpirationDateProviding {
    func expirationDate(of token: String) -> Date?
}

public protocol TokenValidationErrorProviding {
    func validationError(for token: String) -> TokenValidationError?
}

public enum TokenValidationError: Error, Equatable {
    case malformed
    case missingExp
    case expired(expiry: Date)
    case notYetValid(nbf: Date)
    case notParseable
}

public final class JWTTokenValidator: TokenValidating, TokenExpirationDateProviding, TokenValidationErrorProviding {
    public init() {}

    public func isTokenValid(_ token: String) -> Bool {
        guard let expiry = expirationDate(of: token) else { return false }
        return expiry > Date()
    }

    public func expirationDate(of token: String) -> Date? {
        guard let payload = jwtPayload(token),
              let exp = payload["exp"] as? Double ?? (payload["exp"] as? Int).map({ Double($0) })
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    public func validationError(for token: String) -> TokenValidationError? {
        guard let payload = jwtPayload(token) else {
            return .malformed
        }
        guard let exp = payload["exp"] as? Double ?? (payload["exp"] as? Int).map({ Double($0) }) else {
            return .missingExp
        }
        let expiryDate = Date(timeIntervalSince1970: exp)
        if expiryDate < Date() {
            return .expired(expiry: expiryDate)
        }
        if let nbf = payload["nbf"] as? Double {
            let notBeforeDate = Date(timeIntervalSince1970: nbf)
            if notBeforeDate > Date() {
                return .notYetValid(nbf: notBeforeDate)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func jwtPayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        let payloadSegment = segments[1]
        guard let data = base64UrlDecode(String(payloadSegment)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    }

    private func base64UrlDecode(_ str: String) -> Data? {
        var base64 = str
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem > 0 {
            base64.append(String(repeating: "=", count: 4 - rem))
        }
        return Data(base64Encoded: base64)
    }
}
