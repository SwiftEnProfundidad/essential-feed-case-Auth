import EssentialApp
import SwiftUI
import WebKit
import XCTest

final class CaptchaSnapshotTests: XCTestCase {
    func test_captchaView_allStates_snapshot_by_language_and_scheme() {
        let languages = ["en", "es"]
        let schemes: [(UIUserInterfaceStyle, String, ColorScheme)] = [(.light, "light", .light), (.dark, "dark", .dark)]

        for language in languages {
            for (_, schemeName, colorScheme) in schemes {
                autoreleasepool {
                    var sut: UIViewController? = makeCaptchaView(isVisible: true, colorScheme: colorScheme, initialLoading: false)
                    let snapshot = sut!.view.snapshot()
                    assert(snapshot: snapshot, named: "CAPTCHA_VISIBLE", language: language, scheme: schemeName)
                    forceCleanupWebViews(in: sut!.view)
                    sut?.view.removeFromSuperview()
                    sut = nil
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                }
            }
        }

        for language in languages {
            for (_, schemeName, colorScheme) in schemes {
                autoreleasepool {
                    var sut: UIViewController? = makeCaptchaView(isVisible: false, colorScheme: colorScheme)
                    let snapshot = sut!.view.snapshot()
                    assert(snapshot: snapshot, named: "CAPTCHA_HIDDEN", language: language, scheme: schemeName)
                    forceCleanupWebViews(in: sut!.view)
                    sut?.view.removeFromSuperview()
                    sut = nil
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                }
            }
        }

        for language in languages {
            for (_, schemeName, colorScheme) in schemes {
                autoreleasepool {
                    weak var weakRef: UIViewController?
                    autoreleasepool {
                        let sut = makeCaptchaView(isVisible: true, colorScheme: colorScheme, isLoading: true, initialLoading: true)
                        weakRef = sut
                        let snapshot = sut.view.snapshot()
                        assert(snapshot: snapshot, named: "CAPTCHA_LOADING", language: language, scheme: schemeName)
                        forceCleanupWebViews(in: sut.view)
                        sut.view.removeFromSuperview()
                    }
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                    XCTAssertNil(weakRef, "Memory leak: SUT wasn't deallocated")
                }
            }
        }
    }

    private func makeCaptchaView(
        isVisible: Bool, colorScheme: ColorScheme, isLoading _: Bool = false,
        initialLoading: Bool = false, file: StaticString = #filePath, line: UInt = #line
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

extension UIView {
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
}
