import SwiftUI
import UIKit

public enum AuthComposer {
    @MainActor public static func authViewController(onAuthenticated: @escaping () -> Void, onRecoveryRequested: @escaping () -> Void, onRegisterRequested: @escaping () -> Void) -> UIViewController {
        let loginVC = LoginComposer.composedLoginViewController(
            onAuthenticated: onAuthenticated,
            onRecoveryRequested: onRecoveryRequested,
            onRegisterRequested: onRegisterRequested
        )
        return loginVC
    }
}
