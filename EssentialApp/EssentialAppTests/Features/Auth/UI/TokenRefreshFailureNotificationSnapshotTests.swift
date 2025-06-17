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
            message: "Session expired. Please login again or retry.",
            onRetry: {},
            onLogout: {}
        )
        .environment(\.locale, locale)
        .frame(width: 375, height: 120)
        .background(Color(.systemBackground))
    }

    private func makeGlobalLogoutRequiredNotificationView() -> some View {
        GlobalLogoutRequiredNotificationView(
            message: "Your session has expired. Please login again.",
            onLoginRedirect: {}
        )
        .frame(width: 375, height: 100)
        .background(Color(.systemBackground))
    }

    private func makeNetworkErrorRefreshNotificationView() -> some View {
        NetworkErrorRefreshNotificationView(
            message: "Network error occurred during token refresh. Please try again.",
            onRetry: {},
            onCancel: {}
        )
        .frame(width: 375, height: 140)
        .background(Color(.systemBackground))
    }

    private func assertSnapshot(matching value: UIViewController, as snapshotting: Snapshotting<UIViewController, UIImage>, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true"

        guard let snapshot = snapshotting.snapshot(value) else {
            XCTFail("Failed to create snapshot", file: file, line: line)
            return
        }

        let referenceURL = snapshotDirectory.appendingPathComponent("\(name).png")

        if isRecording || !FileManager.default.fileExists(atPath: referenceURL.path) {
            do {
                try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true, attributes: nil)
                try snapshot.pngData()?.write(to: referenceURL)
                if isRecording {
                    return
                } else {
                    XCTFail("Recorded snapshot: \(name). Re-run test to verify.", file: file, line: line)
                    return
                }
            } catch {
                XCTFail("Failed to save snapshot: \(error)", file: file, line: line)
                return
            }
        }

        guard let referenceData = try? Data(contentsOf: referenceURL),
              let referenceImage = UIImage(data: referenceData)
        else {
            XCTFail("Failed to load reference image: \(name)", file: file, line: line)
            return
        }

        let currentData = snapshot.pngData()!
        let referenceImageData = referenceImage.pngData()!

        if currentData.count == referenceImageData.count {
            let tolerance = 0.02
            if imagesAreSimilar(currentData, referenceImageData, tolerance: tolerance) {
                return
            }
        }

        let failureURL = snapshotDirectory.appendingPathComponent("\(name)-failure.png")
        do {
            try currentData.write(to: failureURL)
            XCTFail("Snapshot \(name) does not match reference. Failure saved to: \(failureURL.path)", file: file, line: line)
        } catch {
            XCTFail("Snapshot \(name) does not match reference but failed to save failure image: \(error)", file: file, line: line)
        }
    }

    private func imagesAreSimilar(_ data1: Data, _ data2: Data, tolerance: Double) -> Bool {
        guard data1.count == data2.count else { return false }

        let bytes1 = data1.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        let bytes2 = data2.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }

        var differences = 0
        for i in 0 ..< bytes1.count {
            if bytes1[i] != bytes2[i] {
                differences += 1
            }
        }

        let differenceRatio = Double(differences) / Double(bytes1.count)
        return differenceRatio <= tolerance
    }

    private var snapshotDirectory: URL {
        let currentFile = URL(fileURLWithPath: "\(#file)")
        return currentFile.deletingLastPathComponent().appendingPathComponent("snapshots")
    }
}

struct Snapshotting<Value, Format> {
    let snapshot: (Value) -> Format?

    static var image: Snapshotting<UIViewController, UIImage> {
        Snapshotting<UIViewController, UIImage> { viewController in
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            window.rootViewController = viewController
            window.makeKeyAndVisible()

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

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
