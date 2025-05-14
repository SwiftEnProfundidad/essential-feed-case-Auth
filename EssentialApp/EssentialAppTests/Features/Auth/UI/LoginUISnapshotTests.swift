
import EssentialApp
import EssentialFeed
import SwiftUI
import XCTest

final class LoginUISnapshotTests: XCTestCase {
    func test_loginView_allStates() {
        let vm = LoginViewModel(
            authenticate: { _, _ in .failure(.invalidCredentials) },
            failedAttemptsStore: InMemoryFailedLoginAttemptsStore()
        )

        let view = LoginView(viewModel: vm)

        // Idle
        vm.errorMessage = nil
        vm.loginSuccess = false
        vm.isLoginBlocked = false
        assertSnapshot(for: view, named: "LOGIN_IDLE")

        // Loading
        vm.errorMessage = nil
        vm.loginSuccess = false
        vm.isLoginBlocked = false
        assertSnapshot(for: view, named: "LOGIN_LOADING")

        // Success
        vm.loginSuccess = true
        vm.errorMessage = nil
        vm.isLoginBlocked = false
        assertSnapshot(for: view, named: "LOGIN_SUCCESS")

        // Error
        vm.loginSuccess = false
        vm.errorMessage = "Invalid Credentials"
        vm.isLoginBlocked = false
        assertSnapshot(for: view, named: "LOGIN_ERROR")

        // Blocked
        vm.isLoginBlocked = true
        vm.errorMessage = nil
        vm.loginSuccess = false
        assertSnapshot(for: view, named: "LOGIN_BLOCKED")
    }

    // MARK: - Helpers

    private func assertSnapshot(for view: some View, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let styles: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]
        let snapshotsFolder = URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")
        for (style, suffix) in styles {
            let hostingController = UIHostingController(rootView: view)
            let snapshot = hostingController.snapshot(for: .iPhone13(style: style))
            let snapshotURL = snapshotsFolder.appendingPathComponent("\(name)_\(suffix).png")
            if !FileManager.default.fileExists(atPath: snapshotURL.path) {
                record(snapshot: snapshot, named: "\(name)_\(suffix)", file: file, line: line)
            } else {
                assert(snapshot: snapshot, named: "\(name)_\(suffix)", file: file, line: line)
            }
        }
    }
}
