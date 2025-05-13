import Foundation

class URLProtocolStub: URLProtocol {
    private static var stubData: Data?
    private static var stubResponse: URLResponse?
    private static var stubError: Error?
    private static var requestObserver: ((URLRequest) -> Void)?

    private static let queue = DispatchQueue(label: "URLProtocolStub.queue")
    private var isCompleted = false

    static var hangRequests: Bool = false

    static func stub(data: Data?, response: URLResponse?, error: Error?) {
        queue.sync {
            stubData = data
            stubResponse = response
            stubError = error
        }
    }

    static func observeRequests(observer: @escaping (URLRequest) -> Void) {
        queue.sync {
            requestObserver = observer
        }
    }

    static func removeStub() {
        queue.sync {
            stubData = nil
            stubResponse = nil
            stubError = nil
            requestObserver = nil
            hangRequests = false
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard !isCompleted else { return }

        URLProtocolStub.queue.sync {
            URLProtocolStub.requestObserver?(request)
        }

        if URLProtocolStub.hangRequests {
            return
        }

        var didReportClientEvent = false
        var currentStubError: Error?
        var currentStubResponse: URLResponse?
        var currentStubData: Data?

        URLProtocolStub.queue.sync {
            currentStubError = URLProtocolStub.stubError
            currentStubResponse = URLProtocolStub.stubResponse
            currentStubData = URLProtocolStub.stubData
        }

        if let error = currentStubError {
            client?.urlProtocol(self, didFailWithError: error)
            didReportClientEvent = true
        }

        if !didReportClientEvent, let response = currentStubResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            didReportClientEvent = true

            if let data = currentStubData {
                client?.urlProtocol(self, didLoad: data)
            }
        }

        if !didReportClientEvent {
            let protocolError = NSError(
                domain: NSURLErrorDomain,
                code: URLError.unknown.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "URLProtocolStub: La solicitud finalizó sin una respuesta o error específico provisto por el stub, o con datos pero sin respuesta."]
            )
            client?.urlProtocol(self, didFailWithError: protocolError)
        }

        client?.urlProtocolDidFinishLoading(self)
        isCompleted = true
    }

    override func stopLoading() {
        guard !isCompleted else { return }

        let cancelledError = URLError(.cancelled)
        client?.urlProtocol(self, didFailWithError: cancelledError)
        isCompleted = true
    }
}
