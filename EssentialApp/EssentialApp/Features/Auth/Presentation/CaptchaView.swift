import SwiftUI
import WebKit

public struct CaptchaView: View {
    @Binding public var token: String?
    let onTokenReceived: (String) -> Void
    public let isVisible: Bool

    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading: Bool

    public init(
        token: Binding<String?>,
        onTokenReceived: @escaping (String) -> Void,
        isVisible: Bool,
        initialLoading: Bool = true
    ) {
        self._token = token
        self.onTokenReceived = onTokenReceived
        self.isVisible = isVisible

        _isLoading = State(initialValue: initialLoading)
    }

    public var body: some View {
        if isVisible {
            VStack(spacing: 16) {
                Text("Security Verification")
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Please complete the security verification below")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.neumorphicBase(for: colorScheme))
                        .frame(height: 250)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                        )

                    if isLoading {
                        ProgressView("Loading verification...")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    } else {
                        CaptchaWebView(token: $token, onTokenReceived: onTokenReceived)
                            .frame(height: 250)
                            .cornerRadius(8)
                    }
                }

                Button("Refresh") {
                    refreshCaptcha()
                }
                .font(.caption)
                .foregroundColor(AppTheme.Colors.accentLimeGreen(for: colorScheme))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.neumorphicBase(for: colorScheme))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .onAppear {
                guard isLoading else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoading = false
                }
            }
        }
    }

    private func refreshCaptcha() {
        isLoading = true
        token = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
}

struct CaptchaWebView: UIViewRepresentable {
    @Binding var token: String?
    let onTokenReceived: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <script src="https://www.google.com/recaptcha/api.js" async defer></script>
            <style>
                body { margin: 0; padding: 10px; display: flex; justify-content: center; align-items: center; min-height: 230px; /* Adjusted for new frame height */ }
                .g-recaptcha { transform: scale(1.15); transform-origin: center; /* Increased scale slightly */ }
            </style>
        </head>
        <body>
            <div class="g-recaptcha" 
                 data-sitekey="6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI" 
                 data-callback="onCaptchaSuccess"
                 data-size="compact">
            </div>
            <script>
                function onCaptchaSuccess(token) {
                    window.webkit.messageHandlers.captcha.postMessage(token);
                }
            </script>
        </body>
        </html>
        """

        webView.configuration.userContentController.add(context.coordinator, name: "captcha")
        webView.loadHTMLString(htmlContent, baseURL: URL(string: "http://localhost"))

        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTokenReceived: onTokenReceived, token: $token)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onTokenReceived: (String) -> Void
        private var tokenBinding: Binding<String?>
        weak var webView: WKWebView?

        init(onTokenReceived: @escaping (String) -> Void, token: Binding<String?>) {
            self.onTokenReceived = onTokenReceived
            self.tokenBinding = token
        }

        func userContentController(
            _: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            if message.name == "captcha", let token = message.body as? String {
                tokenBinding.wrappedValue = token
                onTokenReceived(token)
            }
        }

        deinit {
            webView?.stopLoading()
            webView?.navigationDelegate = nil
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "captcha")
        }
    }
}
