import EssentialApp
import EssentialFeed
import XCTest

final class PasswordRecoverySwiftUIViewModelTests: XCTestCase {
    func test_init_doesNotSendFeedback() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.feedbackMessage, "")
        XCTAssertFalse(sut.isSuccess)
        XCTAssertFalse(sut.showingFeedback)
    }

    func test_recoverPassword_success_displaysSuccessFeedback() {
        let (sut, useCaseSpy) = makeSUT()
        let exp = expectation(description: "Wait for async completion")
        sut.email = "user@email.com"
        sut.recoverPassword()
        useCaseSpy.completeRecovery(with: .success(PasswordRecoveryResponse(message: "OK")))

        DispatchQueue.main.async {
            XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
            XCTAssertTrue(sut.isSuccess)
            XCTAssertTrue(sut.showingFeedback)
            XCTAssertEqual(sut.feedbackMessage, "OK")
            XCTAssertEqual(sut.feedbackTitle, "Éxito")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func test_recoverPassword_failure_displaysErrorFeedback() {
        let (sut, useCaseSpy) = makeSUT()
        let exp = expectation(description: "Wait for async completion")
        sut.email = "user@email.com"
        sut.recoverPassword()
        useCaseSpy.completeRecovery(with: .failure(.emailNotFound))

        DispatchQueue.main.async {
            XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
            XCTAssertFalse(sut.isSuccess)
            XCTAssertTrue(sut.showingFeedback)
            XCTAssertEqual(sut.feedbackMessage, "No account associated with that email.")
            XCTAssertEqual(sut.feedbackTitle, "Error")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func test_onFeedbackDismiss_hidesFeedback() {
        let (sut, useCaseSpy) = makeSUT()
        let exp = expectation(description: "Wait for async completion")
        sut.email = "user@email.com"
        sut.recoverPassword()
        useCaseSpy.completeRecovery(with: .success(PasswordRecoveryResponse(message: "OK")))

        DispatchQueue.main.async {
            sut.onFeedbackDismiss()
            XCTAssertFalse(sut.showingFeedback)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
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
        let (sut, useCaseSpy) = makeSUT()
        let exp = expectation(description: "Wait for async completion")
        sut.email = "user@email.com"
        sut.recoverPassword()

        useCaseSpy.completeRecovery(with: .success(PasswordRecoveryResponse(message: "OK")))

        DispatchQueue.main.async {
            XCTAssertTrue(sut.showingFeedback)
            sut.email = "nuevo@email.com"
            XCTAssertFalse(sut.showingFeedback)
            XCTAssertEqual(sut.feedbackMessage, "")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func test_recoverPassword_failureUnknown_displaysGenericErrorFeedback() {
        let (sut, useCaseSpy) = makeSUT()
        let exp = expectation(description: "Wait for async completion")
        sut.email = "user@email.com"
        sut.recoverPassword()
        useCaseSpy.completeRecovery(with: .failure(.unknown))

        DispatchQueue.main.async {
            XCTAssertEqual(useCaseSpy.receivedEmails, ["user@email.com"])
            XCTAssertFalse(sut.isSuccess)
            XCTAssertTrue(sut.showingFeedback)
            XCTAssertEqual(sut.feedbackMessage, "Unknown error. Please try again.")
            XCTAssertEqual(sut.feedbackTitle, "Error")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func test_doesNotShowFeedback_ifEmailChangesBeforeResponse() {
        let (sut, useCaseSpy) = makeSUT()
        sut.email = "primero@email.com"

        sut.recoverPassword()
        sut.email = "segundo@email.com"

        useCaseSpy.completeRecovery(with: .success(PasswordRecoveryResponse(message: "OK")))

        XCTAssertEqual(sut.feedbackMessage, "")
        XCTAssertFalse(sut.showingFeedback)
        XCTAssertTrue(useCaseSpy.receivedEmails.count == 1, "El use case no debe recibir múltiples emails")
    }

    func test_emailChange_toSameValue_doesNotHideFeedback() {
        let (sut, useCaseSpy) = makeSUT()
        let exp = expectation(description: "Wait for async completion")
        sut.email = "user@email.com"
        sut.recoverPassword()
        useCaseSpy.completeRecovery(with: .success(PasswordRecoveryResponse(message: "OK")))

        DispatchQueue.main.async {
            XCTAssertTrue(sut.showingFeedback)
            sut.email = "user@email.com"
            XCTAssertTrue(sut.showingFeedback)
            XCTAssertEqual(sut.feedbackMessage, "OK")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func test_doesNotShowFeedback_ifEmailChangesBeforeErrorResponse() {
        let (sut, useCaseSpy) = makeSUT()
        sut.email = "primero@email.com"
        sut.recoverPassword()
        sut.email = "segundo@email.com"

        useCaseSpy.completeRecovery(with: .failure(.unknown))
        XCTAssertEqual(sut.feedbackMessage, "")
        XCTAssertFalse(sut.showingFeedback)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> (sut: PasswordRecoverySwiftUIViewModel, useCaseSpy: UserPasswordRecoveryUseCaseSpy) {
        let useCaseSpy = UserPasswordRecoveryUseCaseSpy()
        let sut = PasswordRecoverySwiftUIViewModel(recoveryUseCase: useCaseSpy)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(useCaseSpy, file: file, line: line)
        return (sut, useCaseSpy)
    }

    private final class UserPasswordRecoveryUseCaseSpy: UserPasswordRecoveryUseCase {
        private(set) var receivedEmails = [String]()
        private(set) var receivedIPAddresses = [String?]()
        private(set) var receivedUserAgents = [String?]()
        private var completions: [(Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void] = []

        func recoverPassword(email: String, ipAddress: String? = nil, userAgent: String? = nil, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
            receivedEmails.append(email)
            receivedIPAddresses.append(ipAddress)
            receivedUserAgents.append(userAgent)
            completions.append(completion)
        }

        func completeRecovery(with result: Result<PasswordRecoveryResponse, PasswordRecoveryError>, at index: Int = 0) {
            guard completions.indices.contains(index) else { return }
            let completion = completions.remove(at: index)
            completion(result)
        }
    }
}
