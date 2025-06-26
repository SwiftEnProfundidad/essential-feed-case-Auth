import EssentialApp
import SwiftUI
import WebKit
import XCTest

@MainActor
final class CaptchaSnapshotTests: XCTestCase {
    func test_captchaView_allStates() async {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String, ColorScheme)] = [
            (.light, "light", .light),
            (.dark, "dark", .dark)
        ]

        for language in languages {
            for (uiStyle, schemeName, colorScheme) in schemes {
                let locale = Locale(identifier: language)
                let config = SnapshotConfiguration.iPhone16Pro(style: uiStyle, locale: locale)

                await assertSnapshot(
                    for: makeSUT(isVisible: true, initialLoading: false, colorScheme: colorScheme),
                    config: config, named: "CAPTCHA_VISIBLE", language: language, scheme: schemeName
                )

                await assertSnapshot(
                    for: makeSUT(isVisible: false, initialLoading: false, colorScheme: colorScheme),
                    config: config, named: "CAPTCHA_HIDDEN", language: language, scheme: schemeName
                )

                await assertSnapshot(
                    for: makeSUT(isVisible: true, initialLoading: true, colorScheme: colorScheme),
                    config: config, named: "CAPTCHA_LOADING", language: language, scheme: schemeName
                )
            }
        }
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        let envValue = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"]
        return envValue == "1" || envValue == "true"
    }

    private func makeSUT(isVisible: Bool, initialLoading: Bool, colorScheme: ColorScheme, file: StaticString = #filePath, line: UInt = #line) -> UIViewController {
        let view = CaptchaView(
            token: .constant(nil),
            onTokenReceived: { _ in },
            isVisible: isVisible,
            initialLoading: initialLoading
        )
        .environment(\.colorScheme, colorScheme)
        .padding()
        .background(colorScheme == .dark ? .black : .white)

        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        trackForMemoryLeaks(controller, file: file, line: line)
        return controller
    }

    private func assertSnapshot(
        for controller: UIViewController,
        config: SnapshotConfiguration,
        named: String,
        language: String,
        scheme: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        try? await Task.sleep(nanoseconds: 500_000_000)

        let snapshot = controller.snapshot(for: config)

        if isRecording {
            let snapshotURL = makeSnapshotURL(named: named, language: language, scheme: scheme, file: file)
            let snapshotData = snapshot.pngData()

            do {
                try FileManager.default.createDirectory(
                    at: snapshotURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try snapshotData?.write(to: snapshotURL)
                XCTFail("Record succeeded - use `assert` to compare the snapshot from now on.", file: file, line: line)
            } catch {
                XCTFail("Failed to record snapshot with error: \(error)", file: file, line: line)
            }
        } else {
            assert(
                snapshot: snapshot, named: named, language: language, scheme: scheme,
                file: file, line: line
            )
        }

        forceCleanupWebViews()
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    private func forceCleanupWebViews() {
        let window = UIWindow()
        let webView = WKWebView(frame: .zero)
        window.addSubview(webView)
        webView.removeFromSuperview()
    }
}
