import EssentialFeed
import XCTest

final class LoginPresenterTests: XCTestCase {
    func test_didLoginSuccessfully_notifiesViewAndCleansErrors() {
        let (sut, view) = makeSUTWithUnifiedSpy()

        sut.didLoginSuccessfully()

        XCTAssertTrue(view.didShowLoginSuccess, "View should be notified of login success")
        XCTAssertTrue(view.didClearErrorMessages, "View should clear previous error messages")
    }

    func test_didLoginSuccessfully_clearsErrorAndShowsSuccess_withSeparateSpies() {
        let (sut, successSpy, errorSpy) = makeSUTWithSeparateSpies()

        sut.didLoginSuccessfully()

        XCTAssertEqual(errorSpy.clearErrorMessagesCallCount, 1, "Expected to clear error messages once when login succeeds")
        XCTAssertEqual(successSpy.showLoginSuccessCallCount, 1, "Expected to show login success once when login succeeds")
    }

    func test_didLoginSuccessfully_doesNotCrashIfViewsAreNil() {
        let (useCase, notifier, flowHandler) = makeDependencies()
        let sut = LoginPresenter(
            useCase: useCase,
            notifier: notifier,
            flowHandler: flowHandler,
            successView: nil,
            errorClearingView: nil
        )
        sut.didLoginSuccessfully()
    }

    // MARK: - Helpers

    private func makeSUTWithUnifiedSpy() -> (LoginPresenter, LoginViewSpy) {
        let view = LoginViewSpy()
        let (useCase, notifier, flowHandler) = makeDependencies()
        let sut = LoginPresenter(
            useCase: useCase,
            notifier: notifier,
            flowHandler: flowHandler,
            successView: view,
            errorClearingView: view
        )
        return (sut, view)
    }

    private func makeSUTWithSeparateSpies() -> (LoginPresenter, SuccessViewSpy, ErrorClearingViewSpy) {
        let successSpy = SuccessViewSpy()
        let errorSpy = ErrorClearingViewSpy()
        let (useCase, notifier, flowHandler) = makeDependencies()
        let sut = LoginPresenter(
            useCase: useCase,
            notifier: notifier,
            flowHandler: flowHandler,
            successView: successSpy,
            errorClearingView: errorSpy
        )
        return (sut, successSpy, errorSpy)
    }

    private func makeDependencies() -> (UserLoginUseCase, LoginEventNotifierSpy, LoginFlowHandlerSpy) {
        let loginService = LoginServiceSpy() // Ahora usará el spy compartido
        let useCase = UserLoginUseCase(loginService: loginService)
        let notifier = LoginEventNotifierSpy()
        let flowHandler = LoginFlowHandlerSpy()
        return (useCase, notifier, flowHandler)
    }

    // MARK: - Test Doubles

    private class LoginViewSpy: LoginSuccessPresentingView, LoginErrorClearingPresentingView {
        private(set) var didShowLoginSuccess = false
        private(set) var didClearErrorMessages = false
        func showLoginSuccess() { didShowLoginSuccess = true }
        func clearErrorMessages() { didClearErrorMessages = true }
    }

    private class SuccessViewSpy: LoginSuccessPresentingView {
        private(set) var showLoginSuccessCallCount = 0
        func showLoginSuccess() { showLoginSuccessCallCount += 1 }
    }

    private class ErrorClearingViewSpy: LoginErrorClearingPresentingView {
        private(set) var clearErrorMessagesCallCount = 0
        func clearErrorMessages() { clearErrorMessagesCallCount += 1 }
    }
}
