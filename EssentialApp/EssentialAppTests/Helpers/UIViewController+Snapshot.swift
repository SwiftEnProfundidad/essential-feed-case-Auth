import SwiftUI
import UIKit

struct SnapshotConfiguration {
    let size: CGRect
    let style: UIUserInterfaceStyle
    let contentSize: CGSize?
    let locale: Locale

    static func iPhone13(style: UIUserInterfaceStyle = .light, contentSize _: UIContentSizeCategory? = nil, locale: Locale = Locale(identifier: "en_US")) -> SnapshotConfiguration {
        SnapshotConfiguration(
            size: CGRect(x: 0, y: 0, width: 390, height: 844), // iPhone 13 size
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
                self.snapshot(for: configuration)
            }
        }
        let window = UIWindow(frame: configuration.size)
        window.rootViewController = self
        window.makeKeyAndVisible()
        self.overrideUserInterfaceStyle = configuration.style
        self.view.frame = window.frame
        self.view.layoutIfNeeded()
        window.layoutIfNeeded()

        if let contentSize = configuration.contentSize {
            self.view.bounds.size = contentSize
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
    }
}
