import Foundation

public protocol UserRegistrationResponseMapping {
    func map(data: Data, httpResponse: HTTPURLResponse, for userData: UserRegistrationData) async -> UserRegistrationResult
}

public actor UserRegistrationResponseMapper: UserRegistrationResponseMapping {
    private let notifier: UserRegistrationNotifier?

    public init(notifier: UserRegistrationNotifier? = nil) {
        self.notifier = notifier
    }

    public func map(data: Data, httpResponse: HTTPURLResponse, for userData: UserRegistrationData) async -> UserRegistrationResult {
        switch httpResponse.statusCode {
        case 201:
            await handleSuccessResponse(data: data, userData: userData)
        case 409:
            handleConflictResponse(data: data)
        case 429:
            handleRateLimitResponse(data: data, statusCode: httpResponse.statusCode)
        case 400 ..< 500:
            handleClientError(statusCode: httpResponse.statusCode)
        case 500 ..< 600:
            handleServerError(statusCode: httpResponse.statusCode)
        default:
            handleUnknownError()
        }
    }

    private func handleSuccessResponse(data: Data, userData: UserRegistrationData) async -> UserRegistrationResult {
        do {
            let token = try decodeToken(from: data)
            return .success(TokenAndUser(token: token, user: User(name: userData.name, email: userData.email)))
        } catch {
            return handleError(error)
        }
    }

    private func decodeToken(from data: Data) throws -> Token {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let serverResponse = try decoder.decode(ServerAuthResponse.self, from: data)
        return Token(
            accessToken: serverResponse.token.value,
            expiry: serverResponse.token.expiry,
            refreshToken: nil
        )
    }

    private func handleConflictResponse(data: Data) -> UserRegistrationResult {
        if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
           errorData["error"] == "replay_attack_detected"
        {
            notifyAndReturnError(UserRegistrationError.replayAttackDetected)
        } else {
            notifyAndReturnError(UserRegistrationError.emailAlreadyInUse)
        }
    }

    private func handleRateLimitResponse(data: Data, statusCode: Int) -> UserRegistrationResult {
        if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
           errorData["error"] == "abuse_detected"
        {
            return notifyAndReturnError(UserRegistrationError.abuseDetected)
        } else {
            let clientError = NetworkError.clientError(statusCode: statusCode)
            return notifyAndReturnError(clientError)
        }
    }

    private func handleClientError(statusCode: Int) -> UserRegistrationResult {
        let error = NetworkError.clientError(statusCode: statusCode)
        return notifyAndReturnError(error)
    }

    private func handleServerError(statusCode: Int) -> UserRegistrationResult {
        let error = NetworkError.serverError(statusCode: statusCode)
        return notifyAndReturnError(error)
    }

    private func handleUnknownError() -> UserRegistrationResult {
        notifyAndReturnError(NetworkError.unknown)
    }

    private func handleError(_ error: Error) -> UserRegistrationResult {
        if let tokenError = error as? TokenParsingError {
            notifyAndReturnError(tokenError)
        } else if let decodingError = error as? DecodingError {
            notifyAndReturnError(decodingError)
        } else {
            notifyAndReturnError(error)
        }
    }

    private func notifyAndReturnError(_ error: Error) -> UserRegistrationResult {
        // No notificamos aquí, dejamos que el caso de uso lo haga
        .failure(error)
    }
}
