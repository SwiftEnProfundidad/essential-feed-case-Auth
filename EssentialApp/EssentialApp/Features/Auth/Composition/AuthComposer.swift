import SwiftUI
import UIKit

public enum AuthComposer {
    @MainActor public static func authViewController(onAuthenticated: @escaping () -> Void, onRecoveryRequested: @escaping () -> Void) -> UIViewController {
        let loginVC = LoginComposer.composedLoginViewController(
            onAuthenticated: onAuthenticated,
            onRecoveryRequested: onRecoveryRequested
        )
        return loginVC
    }
}
