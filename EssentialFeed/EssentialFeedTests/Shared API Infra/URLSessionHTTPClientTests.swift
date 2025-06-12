import EssentialFeed
import XCTest

class URLSessionHTTPClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        URLProtocolStub.removeStub()
    }

    func test_getFromURL_performsGETRequestWithURL() async {
        let url = anyURL()
        let exp = expectation(description: "Wait for request")

        URLProtocolStub.observeRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }

        URLProtocolStub.stub(data: anyData(), response: anyHTTPURLResponse(), error: nil)

        let (sut, _) = makeSUT()
        _ = try? await sut.send(anyURLRequest())

        await fulfillment(of: [exp], timeout: 1.0)
    }

    func test_send_whenSwiftTaskIsCancelled_throwsCancellationError() async {
        let (sut, _) = makeSUT()

        URLProtocolStub.hangRequests = true
        URLProtocolStub.observeRequests { _ in }

        let task = Task { () -> (Data, HTTPURLResponse) in
            try await sut.send(anyURLRequest())
        }

        try? await Task.sleep(nanoseconds: 1_000_000)

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected send to throw URLError with code .cancelled, but it succeeded or threw a different error.")
        } catch let error as URLError where error.code == .cancelled {
            XCTAssertEqual(error.code, .cancelled, "Expected cancellation error code")
        } catch {
            XCTFail("Expected send to throw URLError with code .cancelled, but threw \(error) instead.")
        }
    }

    func test_getFromURL_failsOnRequestError() async {
        let requestError = anyNSError()

        let receivedError = await resultErrorFor((data: nil, response: nil, error: requestError))

        XCTAssertEqual((receivedError as NSError?)?.domain, requestError.domain)
        XCTAssertEqual((receivedError as NSError?)?.code, requestError.code)
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() async {
        let invalidCases: [(data: Data?, response: URLResponse?, error: Error?)] = [
            (nil, nil, nil),
            (nil, nonHTTPURLResponse(), nil),
            (anyData(), nil, nil),
            (anyData(), nil, anyNSError()),
            (nil, nonHTTPURLResponse(), anyNSError()),
            (nil, anyHTTPURLResponse(), anyNSError()),
            (anyData(), nonHTTPURLResponse(), anyNSError()),
            (anyData(), anyHTTPURLResponse(), anyNSError()),
            (anyData(), nonHTTPURLResponse(), nil)
        ]

        let (sut, _) = makeSUT()
        let timeout: TimeInterval = 1.0

        for invalidCase in invalidCases {
            URLProtocolStub.stub(data: invalidCase.data, response: invalidCase.response, error: invalidCase.error)

            let request = URLRequest(url: anyURL(), timeoutInterval: timeout)
            var receivedError: Error?
            do {
                _ = try await sut.send(request)
            } catch {
                receivedError = error
            }

            XCTAssertNotNil(receivedError, "Expected error for case: \(invalidCase)", file: #filePath, line: #line)
        }
    }

    func test_getFromURL_succeedsOnHTTPURLResponseWithData() async {
        let data = anyData()
        let response = anyHTTPURLResponse()

        let receivedValues = await resultValuesFor((data: data, response: response, error: nil))

        XCTAssertEqual(receivedValues?.data, data)
        XCTAssertEqual(receivedValues?.response.url, response.url)
        XCTAssertEqual(receivedValues?.response.statusCode, response.statusCode)
    }

    func test_getFromURL_succeedsWithEmptyDataOnHTTPURLResponseWithNilData() async {
        let response = anyHTTPURLResponse()

        let receivedValues = await resultValuesFor((data: nil, response: response, error: nil))

        let emptyData = Data()
        XCTAssertEqual(receivedValues?.data, emptyData)
        XCTAssertEqual(receivedValues?.response.url, response.url)
        XCTAssertEqual(receivedValues?.response.statusCode, response.statusCode)
    }

    func test_complete_withError_atIndexOutOfBounds_whenNoRequestsMade() async {
        let (_, client) = makeSUT()

        await client.complete(with: anyNSError(), at: 0)

        try? await Task.sleep(nanoseconds: 100_000_000)

        let messages = await client.messages
        let errorMessages = messages.filter {
            if case .spyError = $0 { return true }
            return false
        }
        XCTAssertTrue(errorMessages.count >= 1, "Should have at least one error message")
    }

    func test_cancelGetFromURLTask_cancelsURLRequest() async {
        let (sut, _) = makeSUT()
        let exp = expectation(description: "Wait for request")

        URLProtocolStub.observeRequests { _ in exp.fulfill() }
        URLProtocolStub.hangRequests = true

        let task = Task { () -> (Data, HTTPURLResponse) in
            try await sut.send(anyURLRequest())
        }

        await fulfillment(of: [exp], timeout: 1.0)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected task to be cancelled")
        } catch {
            XCTAssertTrue(Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled, "Expected cancellation-related error, got: \(error)")
        }
    }

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: HTTPClient, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let sut = URLSessionHTTPClient(session: session)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        return (sut, client)
    }

    private func result(
        _ values: (Data, HTTPURLResponse)? = nil,
        error: Error? = nil
    ) -> Swift.Result<(Data, HTTPURLResponse), Error> {
        switch (values, error) {
        case let (.some((data, response)), _):
            .success((data, response))
        case let (_, .some(error)):
            .failure(error)
        default:
            .failure(anyNSError())
        }
    }

    private func resultValuesFor(
        _ values: (data: Data?, response: URLResponse?, error: Error?)?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> (data: Data, response: HTTPURLResponse)? {
        let result = await resultFor(values, file: file, line: line)
        switch result {
        case let .success((data, response)):
            return (data, response)
        default:
            XCTFail("Expected success, got \(result) instead", file: file, line: line)
            return nil
        }
    }

    private func resultErrorFor(
        _ values: (data: Data?, response: URLResponse?, error: Error?)? = nil,
        taskHandler: (URLSessionDataTask) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Error? {
        let result = await resultFor(values, taskHandler: taskHandler, file: file, line: line)

        switch result {
        case let .failure(error):
            return error
        default:
            XCTFail("Expected failure, got \(result) instead", file: file, line: line)
            return nil
        }
    }

    private func resultFor(
        _ values: (data: Data?, response: URLResponse?, error: Error?)?,
        taskHandler: (URLSessionDataTask) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Swift.Result<(Data, HTTPURLResponse), Error> {
        values.map { URLProtocolStub.stub(data: $0, response: $1, error: $2) }

        let (sut, _) = makeSUT(file: file, line: line)
        do {
            let (data, response) = try await sut.send(anyURLRequest())
            taskHandler(URLSession.shared.dataTask(with: anyURLRequest()))
            return .success((data, response))
        } catch {
            return .failure(error)
        }
    }

    private func anyURLRequest() -> URLRequest {
        URLRequest(url: anyURL())
    }

    private func anyURL() -> URL {
        URL(string: "http://any-url.com")!
    }

    private func anyData() -> Data {
        Data("any data".utf8)
    }

    private func anyNSError() -> NSError {
        NSError(domain: "any error", code: 0)
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func nonHTTPURLResponse() -> URLResponse {
        URLResponse(
            url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil
        )
    }
}
