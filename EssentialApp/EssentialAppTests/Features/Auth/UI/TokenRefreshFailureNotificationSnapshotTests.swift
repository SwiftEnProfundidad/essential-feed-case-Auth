import EssentialApp
import SwiftUI
import XCTest

final class TokenRefreshFailureNotificationSnapshotTests: XCTestCase {
    func test_tokenRefreshFailureNotification_lightMode_displaysCorrectly() {
        let sut = makeTokenRefreshFailureNotificationView()

        let hostingController = UIHostingController(rootView: sut)
        hostingController.overrideUserInterfaceStyle = .light

        assertSnapshot(matching: hostingController, as: .image, named: "TOKEN_REFRESH_FAILURE_LIGHT")
    }

    func test_tokenRefreshFailureNotification_darkMode_displaysCorrectly() {
        let sut = makeTokenRefreshFailureNotificationView()

        let hostingController = UIHostingController(rootView: sut)
        hostingController.overrideUserInterfaceStyle = .dark

        assertSnapshot(matching: hostingController, as: .image, named: "TOKEN_REFRESH_FAILURE_DARK")
    }

    func test_tokenRefreshFailureNotification_spanish_displaysCorrectly() {
        let sut = makeTokenRefreshFailureNotificationView(locale: Locale(identifier: "es"))

        let hostingController = UIHostingController(rootView: sut)
        hostingController.overrideUserInterfaceStyle = .light

        assertSnapshot(matching: hostingController, as: .image, named: "TOKEN_REFRESH_FAILURE_SPANISH")
    }

    func test_globalLogoutRequiredNotification_lightMode_displaysCorrectly() {
        let sut = makeGlobalLogoutRequiredNotificationView()

        let hostingController = UIHostingController(rootView: sut)
        hostingController.overrideUserInterfaceStyle = .light

        assertSnapshot(matching: hostingController, as: .image, named: "GLOBAL_LOGOUT_REQUIRED_LIGHT")
    }

    func test_globalLogoutRequiredNotification_darkMode_displaysCorrectly() {
        let sut = makeGlobalLogoutRequiredNotificationView()

        let hostingController = UIHostingController(rootView: sut)
        hostingController.overrideUserInterfaceStyle = .dark

        assertSnapshot(matching: hostingController, as: .image, named: "GLOBAL_LOGOUT_REQUIRED_DARK")
    }

    func test_networkErrorDuringRefresh_displaysRetryOption() {
        let sut = makeNetworkErrorRefreshNotificationView()

        let hostingController = UIHostingController(rootView: sut)
        hostingController.overrideUserInterfaceStyle = .light

        assertSnapshot(matching: hostingController, as: .image, named: "NETWORK_ERROR_REFRESH_RETRY")
    }

    private func makeTokenRefreshFailureNotificationView(locale: Locale = Locale(identifier: "en")) -> some View {
        TokenRefreshFailureNotificationView(
            message: NSLocalizedString("token_refresh_failed_message", comment: ""),
            onRetry: {},
            onLogout: {}
        )
        .environment(\.locale, locale)
        .frame(width: 375, height: 120)
        .background(Color(.systemBackground))
    }

    private func makeGlobalLogoutRequiredNotificationView() -> some View {
        GlobalLogoutRequiredNotificationView(
            message: NSLocalizedString("session_expired_login_required", comment: ""),
            onLoginRedirect: {}
        )
        .frame(width: 375, height: 100)
        .background(Color(.systemBackground))
    }

    private func makeNetworkErrorRefreshNotificationView() -> some View {
        NetworkErrorRefreshNotificationView(
            message: NSLocalizedString("network_error_during_refresh", comment: ""),
            onRetry: {},
            onCancel: {}
        )
        .frame(width: 375, height: 140)
        .background(Color(.systemBackground))
    }

    private func assertSnapshot(matching value: UIViewController, as snapshotting: Snapshotting<UIViewController, UIImage>, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let snapshot = snapshotting.snapshot(value) else {
            XCTFail("Failed to create snapshot", file: file, line: line)
            return
        }

        let referenceURL = snapshotDirectory.appendingPathComponent("\(name).png")

        if !FileManager.default.fileExists(atPath: referenceURL.path) {
            try! snapshot.pngData()?.write(to: referenceURL)
            XCTFail("Recorded snapshot: \(name). Re-run test to verify.", file: file, line: line)
            return
        }

        guard let referenceData = try? Data(contentsOf: referenceURL),
              let referenceImage = UIImage(data: referenceData)
        else {
            XCTFail("Failed to load reference image: \(name)", file: file, line: line)
            return
        }

        let currentData = snapshot.pngData()!
        let referenceImageData = referenceImage.pngData()!

        if currentData != referenceImageData {
            let failureURL = snapshotDirectory.appendingPathComponent("\(name)-failure.png")
            try! currentData.write(to: failureURL)
            XCTFail("Snapshot \(name) does not match reference. Failure saved to: \(failureURL.path)", file: file, line: line)
        }
    }

    private var snapshotDirectory: URL {
        let bundle = Bundle(for: type(of: self))
        return bundle.bundleURL.deletingLastPathComponent().appendingPathComponent("snapshots")
    }
}

struct Snapshotting<Value, Format> {
    let snapshot: (Value) -> Format?

    static var image: Snapshotting<UIViewController, UIImage> {
        Snapshotting<UIViewController, UIImage> { viewController in
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = viewController
            window.makeKeyAndVisible()

            viewController.view.layoutIfNeeded()

            let renderer = UIGraphicsImageRenderer(bounds: viewController.view.bounds)
            return renderer.image { _ in
                viewController.view.drawHierarchy(in: viewController.view.bounds, afterScreenUpdates: true)
            }
        }
    }
}

struct TokenRefreshFailureNotificationView: View {
    let message: String
    let onRetry: () -> Void
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer()
            }

            HStack(spacing: 16) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)

                Button("Logout", action: onLogout)
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.white)

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct GlobalLogoutRequiredNotificationView: View {
    let message: String
    let onLoginRedirect: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer()
            }

            HStack {
                Button("Go to Login", action: onLoginRedirect)
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct NetworkErrorRefreshNotificationView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundColor(.blue)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer()
            }

            HStack(spacing: 16) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
