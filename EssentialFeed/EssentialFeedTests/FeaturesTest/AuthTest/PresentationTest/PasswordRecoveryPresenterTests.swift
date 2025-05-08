// CU: PasswordRecoveryPresenter
// Checklist:

import EssentialFeed
import XCTest

final class PasswordRecoveryPresenterTests: XCTestCase {
    func test_presenter_deliversSuccessViewModel_onSuccessfulRecovery() {
        let (sut, view) = makeSUT()
        let response = PasswordRecoveryResponse(message: "Check your email")

        sut.didRecoverPassword(with: .success(response))

        XCTAssertEqual(view.messages, [
            PasswordRecoveryViewModel(message: "Check your email", isSuccess: true)
        ])
    }

    func test_presenter_deliversInvalidEmailErrorViewModel_onInvalidEmailError() {
        let (sut, view) = makeSUT()

        sut.didRecoverPassword(with: .failure(.invalidEmailFormat))

        XCTAssertEqual(view.messages, [
            PasswordRecoveryViewModel(message: "El email no tiene un formato válido.", isSuccess: false)
        ])
    }

    func test_presenter_deliversEmailNotFoundErrorViewModel_onEmailNotFoundError() {
        let (sut, view) = makeSUT()

        sut.didRecoverPassword(with: .failure(.emailNotFound))

        XCTAssertEqual(view.messages, [
            PasswordRecoveryViewModel(message: "No existe ninguna cuenta asociada a ese email.", isSuccess: false)
        ])
    }

    func test_presenter_deliversNetworkErrorViewModel_onNetworkError() {
        let (sut, view) = makeSUT()

        sut.didRecoverPassword(with: .failure(.network))

        XCTAssertEqual(view.messages, [
            PasswordRecoveryViewModel(message: "Error de conexión. Inténtalo de nuevo.", isSuccess: false)
        ])
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (PasswordRecoveryPresenter, ViewSpy) {
        let view = ViewSpy()
        let sut = PasswordRecoveryPresenter(view: view)
        trackForMemoryLeaks(view, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, view)
    }

    private class ViewSpy: PasswordRecoveryView {
        private(set) var messages = [PasswordRecoveryViewModel]()
        func display(_ viewModel: PasswordRecoveryViewModel) {
            messages.append(viewModel)
        }
    }
}
