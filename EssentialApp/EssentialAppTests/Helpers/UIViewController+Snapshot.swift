import SwiftUI
import UIKit

struct SnapshotConfiguration {
    let size: CGRect
    let style: UIUserInterfaceStyle
    let contentSize: CGSize?
    let locale: Locale

    static func iPhone13(
        style: UIUserInterfaceStyle = .light, contentSize _: UIContentSizeCategory? = nil,
        locale: Locale = Locale(identifier: "en_US")
    ) -> SnapshotConfiguration {
        SnapshotConfiguration(
            size: CGRect(x: 0, y: 0, width: 390, height: 844),
            style: style,
            contentSize: nil,
            locale: locale
        )
    }

    static func iPhone16(
        style: UIUserInterfaceStyle = .light, contentSize _: UIContentSizeCategory? = nil,
        locale: Locale = Locale(identifier: "en_US")
    ) -> SnapshotConfiguration {
        SnapshotConfiguration(
            size: CGRect(x: 0, y: 0, width: 430, height: 932),
            style: style,
            contentSize: nil,
            locale: locale
        )
    }
}

extension UIViewController {
    func snapshot(for configuration: SnapshotConfiguration) -> UIImage {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync {
                snapshot(for: configuration)
            }
        }

        let window = UIWindow(frame: configuration.size)
        window.overrideUserInterfaceStyle = configuration.style
        window.rootViewController = self
        window.makeKeyAndVisible()

        RunLoop.main.run(until: Date())

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            self.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        window.isHidden = true
        window.rootViewController = nil

        return image
    }
}
