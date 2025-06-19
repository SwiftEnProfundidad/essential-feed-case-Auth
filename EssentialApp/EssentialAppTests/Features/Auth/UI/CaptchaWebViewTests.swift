import EssentialApp
import SwiftUI
import WebKit
import XCTest

final class CaptchaWebViewTests: XCTestCase {
    func test_captchaView_integrationWithWebKit_rendersWebView() {
        let (hostingController, _) = makeSUT(initialLoading: false)

        let webView = findWKWebView(in: hostingController.view)

        XCTAssertNotNil(webView, "Expected UIHostingController's view to contain a WKWebView when CaptchaView is rendered")

        cleanupWebView(in: hostingController.view)
        hostingController.view.removeFromSuperview()
    }

    func test_captchaView_integration_configuresWebViewNavigationDelegate() {
        let (hostingController, _) = makeSUT(initialLoading: false)

        let webView = findWKWebView(in: hostingController.view)

        XCTAssertNotNil(webView?.navigationDelegate, "Expected the rendered WKWebView's navigationDelegate to be set")

        cleanupWebView(in: hostingController.view)
        hostingController.view.removeFromSuperview()
    }

    func test_captchaView_integration_loadsExpectedHTMLContent() {
        let (hostingController, _) = makeSUT(initialLoading: false)

        let webView = findWKWebView(in: hostingController.view)
        XCTAssertNotNil(webView, "WebView should be present before evaluating JavaScript")

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

        let expectation = XCTestExpectation(description: "Wait for WebView to load HTML content")

        webView?.evaluateJavaScript("document.documentElement.outerHTML") { html, error in
            XCTAssertNil(error, "Expected no error when evaluating JavaScript")
            if let htmlString = html as? String {
                XCTAssertTrue(
                    htmlString.contains("recaptcha"),
                    "Expected HTML content to include reCAPTCHA related content"
                )
                XCTAssertTrue(
                    htmlString.contains("postMessage"),
                    "Expected HTML content to include postMessage callback"
                )
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        cleanupWebView(in: hostingController.view)
        hostingController.view.removeFromSuperview()
    }

    func test_captchaView_withVisibleFalse_doesNotRender() {
        let (hostingController, _) = makeSUT(isVisible: false)

        let webView = findWKWebView(in: hostingController.view)

        XCTAssertNil(webView, "Expected no WKWebView when CaptchaView is not visible")

        hostingController.view.removeFromSuperview()
    }

    func test_captchaView_tokenReceived_triggersCallback() {
        let expectedToken = "test-captcha-token"
        let (hostingController, tokenSpy) = makeSUT(initialLoading: false)

        let webView = findWKWebView(in: hostingController.view)
        XCTAssertNotNil(webView, "WebView should be present before simulating token received")

        simulateTokenReceived(expectedToken, in: hostingController)

        let callbackExpectation = XCTestExpectation(description: "Wait for token callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(
                tokenSpy.receivedTokens, [expectedToken],
                "Expected token callback to be triggered with correct token"
            )
            callbackExpectation.fulfill()
        }
        wait(for: [callbackExpectation], timeout: 2.0)

        cleanupWebView(in: hostingController.view)
        hostingController.view.removeFromSuperview()
    }

    // MARK: - Helpers

    private func makeSUT(
        isVisible: Bool = true,
        initialLoading _: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (UIHostingController<CaptchaView>, CaptchaTokenSpy) {
        let tokenSpy = CaptchaTokenSpy()
        var tokenState: String? = nil
        let tokenBinding = Binding<String?>(
            get: { tokenState },
            set: { tokenState = $0 }
        )

        let captchaView = CaptchaView(
            token: tokenBinding,
            onTokenReceived: tokenSpy.onTokenReceived,
            isVisible: isVisible,
            initialLoading: false
        )

        let hostingController = UIHostingController(rootView: captchaView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        hostingController.view.backgroundColor = .white

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.loadViewIfNeeded()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))

        if isVisible {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        }

        trackForMemoryLeaks(hostingController, file: file, line: line)
        trackForMemoryLeaks(tokenSpy, file: file, line: line)

        return (hostingController, tokenSpy)
    }

    private func simulateTokenReceived(_ token: String, in hostingController: UIHostingController<CaptchaView>) {
        let expectation = XCTestExpectation(description: "Wait for WebView to be ready")

        var attempts = 0
        let maxAttempts = 3

        func attemptTokenSimulation() {
            attempts += 1

            if let webView = self.findWKWebView(in: hostingController.view) {
                let jsCode = "window.webkit.messageHandlers.captcha.postMessage('\(token)');"
                webView.evaluateJavaScript(jsCode) { _, _ in
                    expectation.fulfill()
                }
            } else if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    attemptTokenSimulation()
                }
            } else {
                XCTFail("WebView not found after \(maxAttempts) attempts when trying to simulate token received")
                expectation.fulfill()
            }
        }

        attemptTokenSimulation()
        wait(for: [expectation], timeout: 2.0)
    }

    private func findWKWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        for subview in view.subviews {
            if let webView = findWKWebView(in: subview) {
                return webView
            }
        }
        return nil
    }

    private func forceCleanupWebViews() {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            for scene in windowScenes {
                for window in scene.windows {
                    cleanupWebView(in: window)
                }
            }
        } else {
            UIApplication.shared.keyWindow?.subviews.forEach { view in
                cleanupWebView(in: view)
            }
        }
    }

    private func cleanupWebView(in view: UIView) {
        if let webView = view as? WKWebView {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil

            webView.configuration.userContentController.removeAllUserScripts()
            if #available(iOS 14.0, *) {
                webView.configuration.userContentController.removeAllScriptMessageHandlers()
            } else {
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "captcha")
            }
        }

        view.subviews.forEach { cleanupWebView(in: $0) }
    }
}

private final class CaptchaTokenSpy {
    private(set) var receivedTokens: [String] = []

    func onTokenReceived(token: String) {
        receivedTokens.append(token)
    }
}
