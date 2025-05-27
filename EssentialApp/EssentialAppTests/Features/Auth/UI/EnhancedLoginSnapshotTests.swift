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
            let idleVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            idleVM.username = "idle_user@email.com"
            idleVM.password = "idle_password"
            idleVM.errorMessage = nil
            idleVM.loginSuccess = false
            idleVM.isLoginBlocked = false
            let idleView = await LoginView(viewModel: idleVM, animationsEnabled: false)
            await waitForRender()
            await recordSnapshot(for: idleView, named: "LOGIN_IDLE", locale: locale)

            let validationVM = makeViewModel(authenticateResult: .failure(.invalidCredentials))
            validationVM.username = ""
            validationVM.password = ""
            validationVM.errorMessage = "Validation error"
            let validationView = await LoginView(viewModel: validationVM, animationsEnabled: false)
            await waitForRender()
            await recordSnapshot(for: validationView, named: "LOGIN_FORM_VALIDATION", locale: locale)

            let successVM = makeViewModel(
                authenticateResult: .success(LoginResponse(token: "valid_token")))
            successVM.username = "success@email.com"
            successVM.password = "valid_password"
            await successVM.login()
            let successView = await LoginView(viewModel: successVM, animationsEnabled: false)
            await waitForRender()
            await recordSnapshot(for: successView, named: "LOGIN_SUCCESS", locale: locale)

            let errorCases: [(LoginError, String)] = [
                (.invalidCredentials, "INVALID_CREDENTIALS"),
                (.network, "NETWORK"),
                (.noConnectivity, "NO_CONNECTIVITY"),
                (.tokenStorageFailed, "TOKEN_STORAGE_FAILED"),
                (.offlineStoreFailed, "OFFLINE_STORE_FAILED")
            ]
            for (error, stateName) in errorCases {
                let errorVM = makeViewModel(authenticateResult: .failure(error))
                errorVM.username = "error@email.com"
                errorVM.password = "wrong_password"
                await errorVM.login()
                let errorView = await LoginView(viewModel: errorVM, animationsEnabled: false)
                await waitForRender()
                await recordSnapshot(for: errorView, named: "LOGIN_ERROR_\(stateName)", locale: locale)
            }

            let blockedStore = InMemoryFailedLoginAttemptsStore()
            let blockedSecurityUseCase = LoginSecurityUseCase(store: blockedStore, maxAttempts: 1)
            let blockedVM = LoginViewModel(
                authenticate: { _, _ in .failure(.invalidCredentials) },
                loginSecurity: blockedSecurityUseCase
            )
            blockedVM.username = "blocked@email.com"
            blockedVM.password = "blocked_password"
            await blockedVM.login()
            await blockedVM.login()
            let blockedView = await LoginView(viewModel: blockedVM, animationsEnabled: false)
            await waitForRender()
            await recordSnapshot(for: blockedView, named: "LOGIN_ACCOUNT_LOCKED", locale: locale)
        }
    }

    // MARK: - Helpers

    private func makeViewModel(
        authenticateResult: Result<LoginResponse, LoginError> = .failure(LoginError.invalidCredentials)
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

    @MainActor
    private func waitForRender() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }

    @MainActor
    private func recordSnapshot(for view: some View, named name: String, locale: Locale, file: StaticString = #filePath, line: UInt = #line) async {
        let styles: [(UIUserInterfaceStyle, String)] = [
            (.light, "light"),
            (.dark, "dark")
        ]

        let snapshotsFolder = URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")

        for (style, styleName) in styles {
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.overrideUserInterfaceStyle = style

            let contentView =
                view
                    .environment(\.locale, .init(identifier: locale.identifier))
                    .preferredColorScheme(style == .light ? .dark : .light)
                    .frame(
                        width: SnapshotConfiguration.iPhone13().size.width,
                        height: SnapshotConfiguration.iPhone13().size.height
                    )

            let viewController = UIHostingController(rootView: contentView)
            viewController.view.frame = window.bounds

            window.rootViewController = viewController
            window.makeKeyAndVisible()

            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let renderer = UIGraphicsImageRenderer(bounds: viewController.view.bounds)
            let snapshot = renderer.image { _ in
                viewController.view.drawHierarchy(
                    in: viewController.view.bounds,
                    afterScreenUpdates: true
                )
            }

            let folderPath =
                snapshotsFolder
                    .appendingPathComponent(locale.identifier)
                    .appendingPathComponent(styleName)

            try? FileManager.default.createDirectory(
                at: folderPath,
                withIntermediateDirectories: true
            )

            let fileURL = folderPath.appendingPathComponent("\(name).png")

            if let data = snapshot.pngData() {
                try? data.write(to: fileURL)
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
