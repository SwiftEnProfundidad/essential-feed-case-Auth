import XCTest
import EssentialApp
import EssentialFeed

final class PasswordRecoverySwiftUIViewModelTests: XCTestCase {
	func test_init_doesNotSendFeedback() {
		let (sut, _) = makeSUT()
		XCTAssertEqual(sut.feedbackMessage, "")
		XCTAssertFalse(sut.isSuccess)
		XCTAssertFalse(sut.showingFeedback)
	}
	
	func test_recoverPassword_success_displaysSuccessFeedback() {
		let (sut, useCaseSpy) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
		sut.email = "user@email.com"
		sut.recoverPassword()
		XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
		XCTAssertTrue(sut.isSuccess)
		XCTAssertTrue(sut.showingFeedback)
		XCTAssertEqual(sut.feedbackMessage, "OK")
		XCTAssertEqual(sut.feedbackTitle, "Éxito")
	}
	
	func test_recoverPassword_failure_displaysErrorFeedback() {
		let (sut, useCaseSpy) = makeSUT(result: .failure(.emailNotFound))
		sut.email = "user@email.com"
		sut.recoverPassword()
		XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
		XCTAssertFalse(sut.isSuccess)
		XCTAssertTrue(sut.showingFeedback)
		XCTAssertEqual(sut.feedbackMessage, "No existe ninguna cuenta asociada a ese email.")
		XCTAssertEqual(sut.feedbackTitle, "Error")
	}
	
	func test_onFeedbackDismiss_hidesFeedback() {
		let (sut, _) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
		sut.email = "user@email.com"
		sut.recoverPassword()
		sut.onFeedbackDismiss()
		XCTAssertFalse(sut.showingFeedback)
	}

	func test_recoverPassword_withEmptyEmail_doesNotCallUseCaseAndDoesNotShowFeedback() {
		let (sut, useCaseSpy) = makeSUT()
		sut.email = ""
		sut.recoverPassword()
		XCTAssertTrue(useCaseSpy.receivedEmails.isEmpty)
		XCTAssertEqual(sut.feedbackMessage, "")
		XCTAssertFalse(sut.showingFeedback)
	}

	func test_changingEmailAfterFeedback_hidesFeedback() {
		let (sut, _) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
		sut.email = "user@email.com"
		sut.recoverPassword()
		XCTAssertTrue(sut.showingFeedback)
		// Simula que el usuario cambia el email
		sut.email = "nuevo@email.com"
		XCTAssertFalse(sut.showingFeedback)
		XCTAssertEqual(sut.feedbackMessage, "")
	}

	func test_recoverPassword_failureUnknown_displaysGenericErrorFeedback() {
		let (sut, useCaseSpy) = makeSUT(result: .failure(.unknown))
		sut.email = "user@email.com"
		sut.recoverPassword()
		XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
		XCTAssertFalse(sut.isSuccess)
		XCTAssertTrue(sut.showingFeedback)
		XCTAssertEqual(sut.feedbackMessage, "Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo más tarde.")
		XCTAssertEqual(sut.feedbackTitle, "Error")
	}
	
	// MARK: - Helpers
	private func makeSUT(result: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .success(PasswordRecoveryResponse(message: "OK")), file: StaticString = #file, line: UInt = #line) -> (sut: PasswordRecoverySwiftUIViewModel, useCaseSpy: UserPasswordRecoveryUseCaseSpy) {
		let useCaseSpy = UserPasswordRecoveryUseCaseSpy()
		useCaseSpy.result = result
		let sut = PasswordRecoverySwiftUIViewModel(recoveryUseCase: useCaseSpy)
		sut.presenter = PasswordRecoveryPresenter(view: sut)
		trackForMemoryLeaks(sut, file: file, line: line)
		trackForMemoryLeaks(useCaseSpy, file: file, line: line)
		return (sut, useCaseSpy)
	}
	
	private final class UserPasswordRecoveryUseCaseSpy: UserPasswordRecoveryUseCase {
		private(set) var receivedEmails = [String]()
		var result: Result<PasswordRecoveryResponse, PasswordRecoveryError> = .success(PasswordRecoveryResponse(message: "OK"))
		
		func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
			receivedEmails.append(email)
			completion(result)
		}
	}
	
}

