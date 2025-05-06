
import UIKit

final class FakeRefreshControl: UIRefreshControl {
    private var _isRefreshing: Bool = false

    override var isRefreshing: Bool { _isRefreshing }

    override func beginRefreshing() {
        guard !isHidden else { return } // Evitar "offscreen beginRefreshing" si está oculto
        _isRefreshing = true
        // Disparamos el evento valueChanged manualmente porque no estamos en una UI real
        // y el sistema no lo hará por nosotros solo con beginRefreshing().
        // Esto es importante si el ListViewController o su presenter reaccionan a este evento.
        // Sin embargo, el ListViewController.onRefresh se llama programáticamente.
        // Si el presenter actualiza el refreshControl y luego el VC reacciona al valueChanged para llamar a onRefresh,
        // podríamos tener una doble llamada. Pero usualmente, el UIRefreshControl se usa para que el *usuario*
        // tire, lo que dispara valueChanged, y el VC llama a onRefresh.
        // Si el onRefresh se llama programáticamente (como en viewDidLoad o por un botón),
        // entonces el presenter.didStartLoading() es el que pone el refreshControl en estado de carga.
        // Por simplicidad, no disparamos valueChanged aquí a menos que sea necesario.
    }

    override func endRefreshing() {
        _isRefreshing = false
    }
}
