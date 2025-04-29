import XCTest
import EssentialApp
@testable import EssentialFeed

final class PasswordRecoverySwiftUIViewModelTests: XCTestCase {
    func test_init_doesNotSendFeedback() {
        let (_, presenter) = makeSUT()
        XCTAssertEqual(presenter.messages, [])
    }

    func test_recoverPassword_success_displaysSuccessFeedback() {
        let (sut, presenter) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
        sut.email = "user@email.com"
        sut.recoverPassword()
        XCTAssertEqual(presenter.messages, [PasswordRecoveryViewModel(message: "OK", isSuccess: true)])
        XCTAssertTrue(sut.isSuccess)
        XCTAssertTrue(sut.showingFeedback)
        XCTAssertEqual(sut.feedbackMessage, "OK")
        XCTAssertEqual(sut.feedbackTitle, "Éxito")
    }

    func test_recoverPassword_failure_displaysErrorFeedback() {
        let (sut, presenter) = makeSUT(result: .failure(.emailNotFound))
        sut.email = "user@email.com"
        sut.recoverPassword()
        XCTAssertEqual(presenter.messages, [PasswordRecoveryViewModel(message: "El email no existe", isSuccess: false)])
        XCTAssertFalse(sut.isSuccess)
        XCTAssertTrue(sut.showingFeedback)
        XCTAssertEqual(sut.feedbackMessage, "El email no existe")
        XCTAssertEqual(sut.feedbackTitle, "Error")
    }

    func test_onFeedbackDismiss_hidesFeedback() {
        let (sut, _) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
        sut.email = "user@email.com"
        sut.recoverPassword()
        sut.onFeedbackDismiss()
        XCTAssertFalse(sut.showingFeedback)
    }

    // MARK: - Helpers
    private func makeSUT(result: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .success(PasswordRecoveryResponse(message: "OK")), file: StaticString = #file, line: UInt = #line) -> (PasswordRecoverySwiftUIViewModel, PasswordRecoveryViewSpy) {
        let viewSpy = PasswordRecoveryViewSpy()
        let useCase = UserPasswordRecoveryUseCaseStub(result: result)
        let sut = PasswordRecoverySwiftUIViewModel(recoveryUseCase: useCase)
        // Inyecta el spy como vista en el presenter
        sut.presenter = PasswordRecoveryPresenter(view: viewSpy)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(viewSpy, file: file, line: line)
        return (sut, viewSpy)
    }
}

private final class PasswordRecoveryViewSpy: PasswordRecoveryView {
    private(set) var messages = [PasswordRecoveryViewModel]()
    func display(_ viewModel: PasswordRecoveryViewModel) {
        messages.append(viewModel)
    }
}

private struct UserPasswordRecoveryUseCaseStub: UserPasswordRecoveryUseCase {
    let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }
    func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}
