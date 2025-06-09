import Foundation

public final class LoginPresenter {
    private let useCase: UserLoginUseCase
    private let notifier: LoginEventNotifier
    private let flowHandler: LoginFlowHandler
    private weak var successView: (any LoginSuccessPresentingView)?
    private weak var errorClearingView: (any LoginErrorClearingPresentingView)?

    public init(
        useCase: UserLoginUseCase,
        notifier: LoginEventNotifier,
        flowHandler: LoginFlowHandler,
        successView: (any LoginSuccessPresentingView)? = nil,
        errorClearingView: (any LoginErrorClearingPresentingView)? = nil
    ) {
        self.useCase = useCase
        self.notifier = notifier
        self.flowHandler = flowHandler
        self.successView = successView
        self.errorClearingView = errorClearingView
    }

    public func login(with credentials: LoginCredentials) async {
        let result = await useCase.login(with: credentials)

        switch result {
        case let .success(response):
            handleSuccess(response)
            notifier.notifySuccess(response: response)
        case let .failure(error):
            notifier.notifyFailure(error: error)
        }

        await flowHandler.handlePostLogin(result: result, credentials: credentials)
    }

    public func didLoginSuccessfully() {
        errorClearingView?.clearErrorMessages()
        successView?.showLoginSuccess()
    }

    private func handleSuccess(_: LoginResponse) {
        errorClearingView?.clearErrorMessages()
        successView?.showLoginSuccess()
    }
}
