//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import EssentialFeed
import Foundation

// CHANGE: HTTPClientStub ahora se conforma al nuevo protocolo HTTPClient
class HTTPClientStub: HTTPClient {
    // REMOVE: Clase interna Task ya no es necesaria con async/await
    // private class Task: HTTPClientTask {
    // 	func cancel() {}
    // }

    // CHANGE: El stub ahora toma una URLRequest y devuelve un Result.
    // El Result contiene directamente (Data, HTTPURLResponse) o un Error.
    private let stub: (URLRequest) -> Result<(Data, HTTPURLResponse), Error>

    // CHANGE: El inicializador toma el nuevo tipo de stub.
    init(stub: @escaping (URLRequest) -> Result<(Data, HTTPURLResponse), Error>) {
        self.stub = stub
    }

    // REMOVE: El antiguo método get(from:completion:)
    // func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) -> HTTPClientTask {
    // 	completion(stub(url))
    // 	return Task()
    // }

    // REMOVE: El antiguo método post(to:body:completion:)
    // (Asumimos que el nuevo protocolo HTTPClient solo tiene `send`)
    // func post(to url: URL, body: [String: String], completion: @escaping (HTTPClient.Result) -> Void) -> HTTPClientTask {
    // 	completion(stub(url))
    // 	return Task()
    // }

    // ADD: Nuevo método send(_:) que conforma al protocolo HTTPClient con async/await
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Aquí podríamos simular un pequeño delay si fuera necesario para pruebas de UI,
        // pero para la mayoría de los stubs, no es estrictamente necesario.
        // try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 segundos

        switch stub(request) {
        case .success(let (data, response)):
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}

extension HTTPClientStub {
    static var offline: HTTPClientStub {
        // CHANGE: El stub ahora toma una URLRequest, pero para 'offline', el input no importa.
        // El error devuelto es un Error genérico.
        HTTPClientStub(stub: { _ in .failure(NSError(domain: "offline", code: 0, userInfo: [NSLocalizedDescriptionKey: "Simulated offline error"])) })
    }

    // CHANGE: La función 'online' ahora toma un closure que acepta una URL (para compatibilidad con el uso existente en FeedAcceptanceTests)
    // y devuelve (Data, HTTPURLResponse) directamente.
    // Internamente, el HTTPClientStub manejará el envolvimiento en Result.success.
    static func online(_ perURLStub: @escaping (URL) -> (Data, HTTPURLResponse)) -> HTTPClientStub {
        HTTPClientStub { request in
            guard let url = request.url else {
                // Si la request no tiene URL, es un caso que el stub original no manejaba.
                // Se puede decidir lanzar un error específico o un fatalError si se espera que siempre exista.
                let noURLError = NSError(domain: "HTTPClientStub.online", code: 1, userInfo: [NSLocalizedDescriptionKey: "Request provided to 'online' stub had no URL"])
                return .failure(noURLError)
            }
            // Llama al closure 'perURLStub' original que solo toma la URL.
            let (data, response) = perURLStub(url)
            return .success((data, response))
        }
    }
}
