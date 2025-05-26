import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class EnhancedLoginSnapshotTests: XCTestCase {
    func test_loginView_allStates() async {
        let localesToTest = [
            Locale(identifier: "en"),
            Locale(identifier: "es")
        ]

        for locale in localesToTest {
            await verifyLoginViewState(
                viewModel: makeViewModel(),
                state: .idle,
                locale: locale
            )

            let successVM = makeViewModel(
                authenticateResult: .success(LoginResponse(token: "valid_token")))
            successVM.loginSuccess = true
            await verifyLoginViewState(
                viewModel: successVM,
                state: .success,
                locale: locale
            )

            let errorStates: [(LoginError, String)] = [
                (.invalidCredentials, "INVALID_CREDENTIALS"),
                (.network, "NETWORK"),
                (.noConnectivity, "NO_CONNECTIVITY"),
                (.tokenStorageFailed, "TOKEN_STORAGE_FAILED"),
                (.offlineStoreFailed, "OFFLINE_STORE_FAILED")
            ]

            for (error, stateName) in errorStates {
                let errorVM = makeViewModel(authenticateResult: .failure(error))
                let blockMessageProvider = DefaultLoginBlockMessageProvider()
                errorVM.errorMessage = blockMessageProvider.message(for: error)
                await verifyLoginViewState(
                    viewModel: errorVM,
                    state: .error(stateName),
                    locale: locale
                )
            }

            let lockedStore = InMemoryFailedLoginAttemptsStore()
            let lockedSecurity = LoginSecurityUseCase(
                store: lockedStore,
                maxAttempts: 3,
                blockDuration: 300,
                timeProvider: { Date() }
            )
            let lockedVM = LoginViewModel(
                authenticate: { _, _ in .failure(.accountLocked(remainingTime: 300)) },
                loginSecurity: lockedSecurity
            )
            lockedVM.errorMessage = "Account is locked"
            lockedVM.isLoginBlocked = true
            await verifyLoginViewState(
                viewModel: lockedVM,
                state: .accountLocked,
                locale: locale
            )

            let validationVM = makeViewModel()
            validationVM.username = ""
            validationVM.password = ""
            await verifyLoginViewState(
                viewModel: validationVM,
                state: .formValidation,
                locale: locale
            )
        }
    }

    // MARK: - Helpers

    private enum ViewState {
        case idle
        case success
        case error(String)
        case accountLocked
        case formValidation
    }

    private func verifyLoginViewState(
        viewModel: LoginViewModel, state: ViewState, locale: Locale, file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let view = await LoginView(viewModel: viewModel)
        let stateName =
            switch state {
            case .idle: "IDLE"
            case .success: "SUCCESS"
            case let .error(error): "ERROR_\(error)"
            case .accountLocked: "ACCOUNT_LOCKED"
            case .formValidation: "FORM_VALIDATION"
            }

        await recordSnapshot(
            for: view,
            named: "LOGIN_\(stateName)",
            locale: locale,
            file: file,
            line: line
        )
    }

    private func makeViewModel(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(.invalidCredentials)
    ) -> LoginViewModel {
        LoginViewModel(
            authenticate: { _, _ in authenticateResult },
            pendingRequestStore: nil,
            loginSecurity: LoginSecurityUseCase(
                store: InMemoryFailedLoginAttemptsStore(),
                maxAttempts: 3,
                blockDuration: 300,
                timeProvider: { Date() }
            )
        )
    }

    @MainActor private func recordSnapshot(
        for view: some View, named name: String, locale: Locale, file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let styles: [(UIUserInterfaceStyle, String)] = [
            (.light, "light"),
            (.dark, "dark")
        ]

        let snapshotsFolder = URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")

        for (style, styleName) in styles {
            let contentView = view
                .environment(\.locale, .init(identifier: locale.identifier))
                .preferredColorScheme(style == .dark ? .dark : .light)
                .environment(\.colorScheme, style == .dark ? .dark : .light)

            let window = UIWindow(frame: UIScreen.main.bounds)
            window.overrideUserInterfaceStyle = style

            let viewController = UIHostingController(rootView: contentView)
            viewController.view.frame = window.bounds

            window.rootViewController = viewController
            window.makeKeyAndVisible()

            try? await Task.sleep(nanoseconds: 100_000_000)

            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()

            try? await Task.sleep(nanoseconds: 100_000_000)

            let backgroundColor = style == .dark ? UIColor.black : UIColor.white
            let renderer = UIGraphicsImageRenderer(size: viewController.view.bounds.size)
            let snapshot = renderer.image { context in
                backgroundColor.setFill()
                context.fill(viewController.view.bounds)
                viewController.view.drawHierarchy(
                    in: viewController.view.bounds,
                    afterScreenUpdates: true
                )
            }

            let localeFolder =
                snapshotsFolder
                    .appendingPathComponent(locale.identifier)
                    .appendingPathComponent(styleName)

            try? FileManager.default.createDirectory(
                at: localeFolder,
                withIntermediateDirectories: true
            )

            let snapshotURL = localeFolder.appendingPathComponent("\(name).png")

            if let data = snapshot.pngData() {
                try? data.write(to: snapshotURL)
                print("Snapshot guardado en: \(snapshotURL.path)")
            } else {
                XCTFail("Failed to generate snapshot data", file: file, line: line)
            }

            window.isHidden = true
            window.rootViewController = nil
        }
    }
}

// MARK: - Test Helpers

private extension View {
    @MainActor func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
