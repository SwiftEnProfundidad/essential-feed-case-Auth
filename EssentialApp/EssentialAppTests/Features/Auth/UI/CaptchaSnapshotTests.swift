import EssentialApp
import SwiftUI
import WebKit
import XCTest

final class CaptchaSnapshotTests: XCTestCase {
    func test_captchaView_visible_light() {
        autoreleasepool {
            var sut: UIViewController? = makeCaptchaView(isVisible: true, colorScheme: .light, initialLoading: false)

            assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_VISIBLE", language: "en", scheme: "light")
            assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_VISIBLE", language: "es", scheme: "light")

            RunLoop.current.run(until: Date())
            forceCleanupWebViews(in: sut!.view)
            sut?.view.removeFromSuperview()
            sut = nil

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    func test_captchaView_visible_dark() {
        autoreleasepool {
            var sut: UIViewController? = makeCaptchaView(isVisible: true, colorScheme: .dark, initialLoading: false)

            assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_VISIBLE", language: "en", scheme: "dark")
            assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_VISIBLE", language: "es", scheme: "dark")

            RunLoop.current.run(until: Date())
            forceCleanupWebViews(in: sut!.view)
            sut?.view.removeFromSuperview()
            sut = nil

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    func test_captchaView_hidden() {
        autoreleasepool {
            var sut: UIViewController? = makeCaptchaView(isVisible: false, colorScheme: .light)

            assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_HIDDEN", language: "en", scheme: "light")
            assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_HIDDEN", language: "es", scheme: "light")

            RunLoop.current.run(until: Date())
            forceCleanupWebViews(in: sut!.view)
            sut?.view.removeFromSuperview()
            sut = nil

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    func test_captchaView_loading_light() {
        var sut: UIViewController? = makeCaptchaView(
            isVisible: true, colorScheme: .light, isLoading: true, initialLoading: true
        )

        assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_LOADING", language: "en", scheme: "light")
        assertSnapshot(sut!.view.snapshot(), named: "CAPTCHA_LOADING", language: "es", scheme: "light")

        RunLoop.current.run(until: Date())
        sut?.view.removeFromSuperview()
        sut = nil
    }

    func test_captchaView_loading_dark() {
        autoreleasepool {
            weak var weakRef: UIViewController?

            autoreleasepool {
                let sut = makeCaptchaView(isVisible: true, colorScheme: .dark, isLoading: true, initialLoading: true)
                weakRef = sut

                assertSnapshot(sut.view.snapshot(), named: "CAPTCHA_LOADING", language: "en", scheme: "dark")
                assertSnapshot(sut.view.snapshot(), named: "CAPTCHA_LOADING", language: "es", scheme: "dark")

                forceCleanupWebViews(in: sut.view)
                sut.view.removeFromSuperview()
            }

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            XCTAssertNil(weakRef, "Memory leak: SUT wasn't deallocated")
        }
    }

    private func makeCaptchaView(
        isVisible: Bool,
        colorScheme: ColorScheme,
        isLoading _: Bool = false,
        initialLoading: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIViewController {
        var tokenValue: String? = nil
        let tokenBinding = Binding<String?>(
            get: { tokenValue },
            set: { tokenValue = $0 }
        )

        let captchaView = CaptchaView(
            token: tokenBinding,
            onTokenReceived: { _ in },
            isVisible: isVisible,
            initialLoading: initialLoading
        )
        .environment(\.colorScheme, colorScheme)
        .frame(width: 320, height: 200)

        let hostingController = UIHostingController(rootView: captchaView)
        hostingController.view.backgroundColor = colorScheme == .dark ? .black : .white
        hostingController.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        hostingController.loadViewIfNeeded()

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))

        trackForMemoryLeaks(hostingController, file: file, line: line)

        return hostingController
    }
}

private extension UIView {
    func snapshot() -> UIImage {
        setNeedsDisplay()
        layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)

        return renderer.image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }
}

extension CaptchaSnapshotTests {
    private func forceCleanupWebViews(in view: UIView) {
        for subview in view.subviews {
            if let webView = subview as? WKWebView {
                webView.stopLoading()
                webView.configuration.userContentController.removeAllUserScripts()
                webView.configuration.userContentController.removeAllScriptMessageHandlers()
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
                webView.scrollView.delegate = nil
                webView.removeFromSuperview()
            } else if !subview.subviews.isEmpty {
                forceCleanupWebViews(in: subview)
            }
        }
    }

    func assertSnapshot(
        _ snapshot: UIImage,
        named name: String,
        language: String,
        scheme: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshotURL = makeSnapshotURL(named: name, language: language, scheme: scheme, file: file)
        let snapshotData = makeSnapshotData(for: snapshot, file: file, line: line)

        let recordMode = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true"

        if recordMode {
            do {
                try FileManager.default.createDirectory(
                    at: snapshotURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                try snapshotData?.write(to: snapshotURL)
                print("✅ Snapshot recorded successfully at: \(snapshotURL)")
                return
            } catch {
                XCTFail("Failed to record snapshot with error: \(error)", file: file, line: line)
            }
        } else {
            guard let storedSnapshotData = try? Data(contentsOf: snapshotURL) else {
                XCTFail(
                    "Failed to load stored snapshot at URL: \(snapshotURL). Use the `record` method (by setting RECORD_SNAPSHOTS=true environment variable) to store a snapshot before asserting.",
                    file: file, line: line
                )
                return
            }

            if snapshotData != storedSnapshotData {
                let temporarySnapshotURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                    .appendingPathComponent(snapshotURL.lastPathComponent)

                try? snapshotData?.write(to: temporarySnapshotURL)

                XCTFail(
                    "New snapshot does not match stored snapshot. New snapshot URL: \(temporarySnapshotURL), Stored snapshot URL: \(snapshotURL)",
                    file: file, line: line
                )
            }
        }
    }

    func makeSnapshotURL(named name: String, language: String, scheme: String, file: StaticString)
        -> URL
    {
        URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")
            .appendingPathComponent(language)
            .appendingPathComponent(scheme)
            .appendingPathComponent("\(name).png")
    }

    private func makeSnapshotData(for snapshot: UIImage, file: StaticString, line: UInt) -> Data? {
        guard let data = snapshot.pngData() else {
            XCTFail("Failed to generate PNG data representation from snapshot", file: file, line: line)
            return nil
        }
        return data
    }
}
