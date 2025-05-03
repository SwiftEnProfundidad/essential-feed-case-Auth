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
		// Simula la respuesta del caso de uso
		useCaseSpy.recoverPasswordCompletions.first?.1(.success(PasswordRecoveryResponse(message: "OK")))
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
		// Simula la respuesta del caso de uso
		useCaseSpy.recoverPasswordCompletions.first?.1(.failure(.emailNotFound))
		XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
		XCTAssertFalse(sut.isSuccess)
		XCTAssertTrue(sut.showingFeedback)
		XCTAssertEqual(sut.feedbackMessage, "No existe ninguna cuenta asociada a ese email.")
		XCTAssertEqual(sut.feedbackTitle, "Error")
	}
	
	func test_onFeedbackDismiss_hidesFeedback() {
		let (sut, useCaseSpy) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
		sut.email = "user@email.com"
		sut.recoverPassword()
		useCaseSpy.recoverPasswordCompletions.first?.1(.success(PasswordRecoveryResponse(message: "OK")))
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
    let (sut, useCaseSpy) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
    sut.email = "user@email.com"
    sut.recoverPassword()
    // Simula la respuesta del caso de uso
    useCaseSpy.recoverPasswordCompletions.first?.1(.success(PasswordRecoveryResponse(message: "OK")))
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
		useCaseSpy.recoverPasswordCompletions.first?.1(.failure(.unknown))
		XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
		XCTAssertFalse(sut.isSuccess)
		XCTAssertTrue(sut.showingFeedback)
		XCTAssertEqual(sut.feedbackMessage, "Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo más tarde.")
		XCTAssertEqual(sut.feedbackTitle, "Error")
	}
	
	func test_doesNotShowFeedback_ifEmailChangesBeforeResponse() {
        let (sut, useCaseSpy) = makeSUT()
        sut.email = "primero@email.com"

        sut.recoverPassword()
        // Cambia el email antes de simular la respuesta
        sut.email = "segundo@email.com"
        // Simula respuesta del use case para el email anterior
        let completion = useCaseSpy.recoverPasswordCompletions.first?.1
        completion?(.success(PasswordRecoveryResponse(message: "OK")))

        XCTAssertEqual(sut.feedbackMessage, "")
        XCTAssertFalse(sut.showingFeedback)
        // Añade assert para verificar si el email cambio limpió feedback
        XCTAssertTrue(useCaseSpy.receivedEmails.count == 1, "El use case no debe recibir múltiples emails")
    }

    func test_emailChange_toSameValue_doesNotHideFeedback() {
    let (sut, useCaseSpy) = makeSUT(result: .success(PasswordRecoveryResponse(message: "OK")))
    sut.email = "user@email.com"
    sut.recoverPassword()
    useCaseSpy.recoverPasswordCompletions.first?.1(.success(PasswordRecoveryResponse(message: "OK")))
    XCTAssertTrue(sut.showingFeedback)
    // Cambia el email al mismo valor
    sut.email = "user@email.com"
    // El feedback debe seguir visible
    XCTAssertTrue(sut.showingFeedback)
    XCTAssertEqual(sut.feedbackMessage, "OK")
}

func test_doesNotShowFeedback_ifEmailChangesBeforeErrorResponse() {
    let (sut, useCaseSpy) = makeSUT(result: .failure(.unknown))
    sut.email = "primero@email.com"
    sut.recoverPassword()
    // Cambia el email antes de simular la respuesta de error
    sut.email = "segundo@email.com"
    useCaseSpy.recoverPasswordCompletions.first?.1(.failure(.unknown))
    XCTAssertEqual(sut.feedbackMessage, "")
    XCTAssertFalse(sut.showingFeedback)
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
        var recoverPasswordCompletions: [(String, (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void)] = []
        
        func recoverPassword(email: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
            receivedEmails.append(email)
            recoverPasswordCompletions.append((email, completion))
        }
    }
	
}
