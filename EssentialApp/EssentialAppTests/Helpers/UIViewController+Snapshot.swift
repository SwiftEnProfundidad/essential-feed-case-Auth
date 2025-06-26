import SwiftUI
import UIKit

struct SnapshotConfiguration {
    let size: CGSize
    let style: UIUserInterfaceStyle
    let contentSize: CGSize?
    let locale: Locale

    static func iPhone13(
        style: UIUserInterfaceStyle = .light, contentSize _: UIContentSizeCategory? = nil,
        locale: Locale = Locale(identifier: "en_US")
    ) -> SnapshotConfiguration {
        SnapshotConfiguration(
            size: CGSize(width: 390, height: 844),
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
            size: CGSize(width: 430, height: 932),
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

        let window = UIWindow(frame: CGRect(origin: .zero, size: configuration.size))
        window.overrideUserInterfaceStyle = configuration.style
        window.windowLevel = .normal
        window.rootViewController = self

        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        {
            window.windowScene = windowScene
        }

        window.isHidden = false
        window.makeKeyAndVisible()

        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        RunLoop.main.run(until: Date()) // Brief run loop pass

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size, format: format)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        window.isHidden = true
        window.rootViewController = nil

        return image
    }
}
