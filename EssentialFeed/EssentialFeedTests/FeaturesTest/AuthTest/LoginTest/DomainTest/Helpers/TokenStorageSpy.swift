var saveError: Error?

func save(_ token: Token) async throws {
    if let error = saveError { throw error }
    messages.append(.save(token))
}

// MARK: - Test helpers
/// Configura la próxima llamada a `save` para lanzar el `error` indicado.
func completeSave(with error: Swift.Error) {
    self.saveError = error
}

/// Configura `save` para no fallar.
func completeSaveSuccessfully() {
    self.saveError = nil
}
