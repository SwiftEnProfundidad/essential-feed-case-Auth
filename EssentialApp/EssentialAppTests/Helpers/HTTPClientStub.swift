//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import EssentialFeed
import Foundation

final class HTTPClientStub: @unchecked Sendable, HTTPClient {
    private let stub: @Sendable (URLRequest) -> Result<(Data, HTTPURLResponse), any Error>

    init(stub: @escaping @Sendable (URLRequest) -> Result<(Data, HTTPURLResponse), any Error>) {
        self.stub = stub
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        switch stub(request) {
        case .success(let (data, response)):
            return (data, response)
        case let .failure(error):
            throw error
        }
    }
}

extension HTTPClientStub {
    static var offline: HTTPClientStub {
        HTTPClientStub(stub: { _ in .failure(NSError(domain: "offline", code: 0, userInfo: [NSLocalizedDescriptionKey: "Simulated offline error"])) })
    }

    static func online(_ perURLStub: @escaping @Sendable (URL) -> (Data, HTTPURLResponse)) -> HTTPClientStub {
        HTTPClientStub { request in
            guard let url = request.url else {
                let noURLError = NSError(domain: "HTTPClientStub.online", code: 1, userInfo: [NSLocalizedDescriptionKey: "Request provided to 'online' stub had no URL"])
                return .failure(noURLError)
            }
            let (data, response) = perURLStub(url)
            return .success((data, response))
        }
    }
}
