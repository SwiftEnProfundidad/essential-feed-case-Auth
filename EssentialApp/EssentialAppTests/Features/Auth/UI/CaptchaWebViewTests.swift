import EssentialApp
import SwiftUI
import WebKit
import XCTest

final class CaptchaWebViewTests: XCTestCase {
    func test_captchaView_integrationWithWebKit_rendersWebView() {
        let (hostingController, _) = makeSUT()

        let webView = findWKWebView(in: hostingController.view)

        XCTAssertNotNil(
            webView,
            "Expected UIHostingController's view to contain a WKWebView when CaptchaView is rendered"
        )
    }

    func test_captchaView_integration_configuresWebViewNavigationDelegate() {
        let (hostingController, _) = makeSUT()

        let webView = findWKWebView(in: hostingController.view)

        XCTAssertNotNil(
            webView?.navigationDelegate, "Expected the rendered WKWebView's navigationDelegate to be set"
        )
    }

    func test_captchaView_integration_loadsExpectedHTMLContent() {
        let (hostingController, _) = makeSUT()

        let webView = findWKWebView(in: hostingController.view)
        XCTAssertNotNil(webView, "WebView should be present before evaluating JavaScript")

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

        wait(for: [expectation], timeout: 10.0)
    }

    func test_captchaView_withVisibleFalse_doesNotRender() {
        let (hostingController, _) = makeSUT(isVisible: false)

        let webView = findWKWebView(in: hostingController.view)

        XCTAssertNil(webView, "Expected no WKWebView when CaptchaView is not visible")
    }

    func test_captchaView_tokenReceived_triggersCallback() {
        let expectedToken = "test-captcha-token"
        let (hostingController, tokenSpy) = makeSUT()

        let webView = findWKWebView(in: hostingController.view)
        XCTAssertNotNil(webView, "WebView should be present before simulating token received")

        simulateTokenReceived(expectedToken, in: hostingController)

        let callbackExpectation = XCTestExpectation(description: "Wait for callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(
                tokenSpy.receivedTokens, [expectedToken],
                "Expected token callback to be triggered with correct token"
            )
            callbackExpectation.fulfill()
        }
        wait(for: [callbackExpectation], timeout: 2.0)
    }

    private func makeSUT(
        isVisible: Bool = true,
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
        hostingController.loadViewIfNeeded()

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))

        trackForMemoryLeaks(hostingController, file: file, line: line)
        trackForMemoryLeaks(tokenSpy, file: file, line: line)

        return (hostingController, tokenSpy)
    }

    private func simulateTokenReceived(
        _ token: String, in hostingController: UIHostingController<CaptchaView>
    ) {
        let expectation = XCTestExpectation(description: "Wait for WebView to be ready")

        if let webView = self.findWKWebView(in: hostingController.view) {
            let jsCode = "window.webkit.messageHandlers.captcha.postMessage('\(token)');"
            webView.evaluateJavaScript(jsCode) { _, _ in
                expectation.fulfill()
            }
        } else {
            XCTFail("WebView not found when trying to simulate token received")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
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
}

private final class CaptchaTokenSpy {
    private(set) var receivedTokens: [String] = []

    func onTokenReceived(token: String) {
        receivedTokens.append(token)
    }
}
