import Foundation
import Combine

public final class LoginViewModel: ObservableObject {
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var errorMessage: String?
    @Published public var loginSuccess: Bool = false
    public let authenticated = PassthroughSubject<Void, Never>()
    
    public init() {}
    
    public func login() {
        print("LoginViewModel: intentando login con \(username)/\(password)")
        if username == "user" && password == "pass" {
            print("LoginViewModel: login OK, mostrando alerta")
            errorMessage = nil
            loginSuccess = true
            authenticated.send(())
        } else {
            print("LoginViewModel: login FAIL")
            errorMessage = "Invalid credentials."
            loginSuccess = false
        }
    }
    
    public var onAuthenticated: (() -> Void)?

    public func onSuccessAlertDismissed() {
        print("LoginViewModel: alerta de éxito cerrada")
        loginSuccess = false
        onAuthenticated?()
    }
}
