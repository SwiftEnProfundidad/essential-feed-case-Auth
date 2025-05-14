
import SwiftUI
import UIKit

public enum AuthComposer {
    public static func authViewController(onAuthenticated: @escaping () -> Void) -> UIViewController {
        let loginVC = LoginComposer.composedViewController(onAuthenticated: onAuthenticated)
        return loginVC
    }
}
