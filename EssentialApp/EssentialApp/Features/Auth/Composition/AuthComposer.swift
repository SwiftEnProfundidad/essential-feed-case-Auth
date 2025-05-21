import SwiftUI
import UIKit

public enum AuthComposer {
    public static func authViewController(
        onAuthenticated: @escaping () -> Void,
        onRecoveryRequested: @escaping () -> Void
    ) -> UIViewController {
        let loginVC = LoginComposer.composedViewController(
            onAuthenticated: onAuthenticated,
            onRecoveryRequested: onRecoveryRequested
        )
        return loginVC
    }
}
