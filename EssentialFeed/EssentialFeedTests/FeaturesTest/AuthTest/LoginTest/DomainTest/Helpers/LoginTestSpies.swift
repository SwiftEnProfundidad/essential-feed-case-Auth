import EssentialFeed
import Foundation

final class LoginPersistenceSpy: LoginPersistence {
    private(set) var savedTokens: [Token] = []
    private(set) var savedCredentials: [LoginCredentials] = []
    private(set) var savedResponses: [LoginResponse] = []
    var saveTokenError: Error?
    var saveCredentialsError: Error?
    var saveLoginDataError: Error?

    func saveToken(_ token: Token) async throws {
        if let error = saveTokenError { throw error }
        savedTokens.append(token)
    }

    func saveOfflineCredentials(_ credentials: LoginCredentials) async throws {
        if let error = saveCredentialsError { throw error }
        savedCredentials.append(credentials)
    }

    func saveLoginData(_ response: LoginResponse, _ credentials: LoginCredentials) async throws {
        if let error = saveLoginDataError { throw error }
        savedResponses.append(response)
        savedCredentials.append(credentials)
    }
}

final class LoginEventNotifierSpy: LoginEventNotifier {
    private(set) var notifiedSuccesses: [LoginResponse] = []
    private(set) var notifiedFailures: [Error] = []
    func notifySuccess(response: LoginResponse) {
        notifiedSuccesses.append(response)
    }

    func notifyFailure(error: Error) {
        notifiedFailures.append(error)
    }
}

final class LoginFlowHandlerSpy: LoginFlowHandler {
    private(set) var handledResults: [(Result<LoginResponse, LoginError>, LoginCredentials)] = []
    func handlePostLogin(result: Result<LoginResponse, LoginError>, credentials: LoginCredentials) {
        handledResults.append((result, credentials))
    }
}
