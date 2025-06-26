import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

@MainActor
final class PasswordRecoverySnapshotTests: XCTestCase {
    func test_passwordRecovery_snapshots() {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

        for language in languages {
            for (uiStyle, schemeName) in schemes {
                let locale = Locale(identifier: language)
                let config = SnapshotConfiguration.iPhone13(style: uiStyle, locale: locale)

                weak var weakSuccessVM: PasswordRecoverySwiftUIViewModel?
                weak var weakSuccessSUT: UIViewController?
                assertSnapshotAndRelease(
                    apiResult: .success(PasswordRecoveryResponse(message: "Recovery email sent!")),
                    config: config,
                    named: "PASSWORD_RECOVERY_SUCCESS",
                    language: language,
                    scheme: schemeName,
                    weakVM: &weakSuccessVM,
                    weakSUT: &weakSuccessSUT
                )
                XCTAssertNil(weakSuccessVM, "Success ViewModel should have been deallocated. Potential memory leak.", file: #filePath, line: #line)
                XCTAssertNil(weakSuccessSUT, "Success SUT should have been deallocated. Potential memory leak.", file: #filePath, line: #line)

                weak var weakErrorVM: PasswordRecoverySwiftUIViewModel?
                weak var weakErrorSUT: UIViewController?
                assertSnapshotAndRelease(
                    apiResult: .failure(.emailNotFound),
                    config: config,
                    named: "PASSWORD_RECOVERY_ERROR",
                    language: language,
                    scheme: schemeName,
                    weakVM: &weakErrorVM,
                    weakSUT: &weakErrorSUT
                )
                XCTAssertNil(weakErrorVM, "Error ViewModel should have been deallocated. Potential memory leak.", file: #filePath, line: #line)
                XCTAssertNil(weakErrorSUT, "Error SUT should have been deallocated. Potential memory leak.", file: #filePath, line: #line)
            }
        }
    }

    private func makeSUT(apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>, config: SnapshotConfiguration, file: StaticString = #filePath, line: UInt = #line) -> (PasswordRecoverySwiftUIViewModel, UIViewController) {
        let api = DummyPasswordRecoveryAPI(result: apiResult)
        let rateLimiter = DummyPasswordRecoveryRateLimiter()
        let tokenManager = DummyPasswordResetTokenManager()
        let auditLogger = DummyPasswordRecoveryAuditLogger()
        let useCase = RemoteUserPasswordRecoveryUseCase(api: api, rateLimiter: rateLimiter, tokenManager: tokenManager, auditLogger: auditLogger)
        let viewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: useCase, mainQueueDispatcher: { $0() })
        viewModel.email = "any@email.com"

        let view = PasswordRecoveryScreen(viewModel: viewModel)
            .frame(width: config.size.width, height: config.size.height)

        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()
        controller.view.backgroundColor = .clear

        trackForMemoryLeaks(api, file: file, line: line)
        trackForMemoryLeaks(rateLimiter, file: file, line: line)
        trackForMemoryLeaks(tokenManager, file: file, line: line)
        trackForMemoryLeaks(auditLogger, file: file, line: line)
        trackForMemoryLeaks(useCase, file: file, line: line)
        trackForMemoryLeaks(viewModel, file: file, line: line)
        trackForMemoryLeaks(controller, file: file, line: line)

        return (viewModel, controller)
    }

    private func assertSnapshot(for controller: UIViewController, config: SnapshotConfiguration, named: String, language: String, scheme: String, file: StaticString = #filePath, line: UInt = #line) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let snapshot = controller.snapshot(for: config)
        assert(snapshot: snapshot, named: named, language: language, scheme: scheme, file: file, line: line)
    }
}

private final class DummyPasswordRecoveryAPI: PasswordRecoveryAPI {
    private let result: Result<PasswordRecoveryResponse, PasswordRecoveryError>
    init(result: Result<PasswordRecoveryResponse, PasswordRecoveryError>) {
        self.result = result
    }

    func recover(email _: String, completion: @escaping (Result<PasswordRecoveryResponse, PasswordRecoveryError>) -> Void) {
        completion(result)
    }
}

private final class DummyPasswordRecoveryRateLimiter: PasswordRecoveryRateLimiter {
    func isAllowed(for _: String) -> Result<Void, PasswordRecoveryError> {
        return .success(())
    }

    func recordAttempt(for _: String, ipAddress _: String?) {}
}

private final class DummyPasswordResetTokenManager: PasswordResetTokenManager {
    func generateResetToken(for email: String) throws -> PasswordResetToken {
        return PasswordResetToken(
            token: "dummy-token",
            email: email,
            expirationDate: Date().addingTimeInterval(900)
        )
    }
}

private final class DummyPasswordRecoveryAuditLogger: PasswordRecoveryAuditLogger {
    func logRecoveryAttempt(_: PasswordRecoveryAuditLog) async throws {}
}

private extension PasswordRecoverySnapshotTests {
    func assertSnapshotAndRelease(
        apiResult: Result<PasswordRecoveryResponse, PasswordRecoveryError>,
        config: SnapshotConfiguration,
        named: String,
        language: String,
        scheme: String,
        weakVM: inout PasswordRecoverySwiftUIViewModel?,
        weakSUT: inout UIViewController?
    ) {
        var strongVM: PasswordRecoverySwiftUIViewModel?
        var strongSUT: UIViewController?

        autoreleasepool {
            let (vm, sut) = makeSUT(apiResult: apiResult, config: config)
            strongVM = vm
            _ = strongVM
            strongSUT = sut
            _ = strongSUT

            weakVM = vm
            weakSUT = sut

            vm.recoverPassword()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.7))
            assertSnapshot(for: sut, config: config, named: named, language: language, scheme: scheme)

            if let hostingController = sut as? UIHostingController<PasswordRecoveryScreen> {
                let dummyRecoveryUseCase = RemoteUserPasswordRecoveryUseCase(
                    api: DummyPasswordRecoveryAPI(result: .success(.init(message: "dummy"))),
                    rateLimiter: DummyPasswordRecoveryRateLimiter(),
                    tokenManager: DummyPasswordResetTokenManager(),
                    auditLogger: DummyPasswordRecoveryAuditLogger()
                )
                let dummyViewModel = PasswordRecoverySwiftUIViewModel(recoveryUseCase: dummyRecoveryUseCase)
                hostingController.rootView = PasswordRecoveryScreen(viewModel: dummyViewModel)
            }

            strongVM = nil
            strongSUT = nil
        }

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.7))
    }
}
