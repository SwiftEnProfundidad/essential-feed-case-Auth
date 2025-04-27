import UIKit

struct SnapshotConfiguration {
    let size: CGRect
    let style: UIUserInterfaceStyle
    let contentSize: CGSize?

    static func iPhone13(style: UIUserInterfaceStyle = .light, contentSize: UIContentSizeCategory? = nil) -> SnapshotConfiguration {
        return SnapshotConfiguration(
            size: CGRect(x: 0, y: 0, width: 390, height: 844), // iPhone 13 size
            style: style,
            contentSize: nil // Puedes añadir lógica para accesibilidad si lo necesitas
        )
    }
}

extension UIViewController {
    func snapshot(for configuration: SnapshotConfiguration) -> UIImage {
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
