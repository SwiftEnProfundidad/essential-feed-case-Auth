//
//  Copyright 2019 Essential Developer. All rights reserved.
//

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

        // ADD: Stub una respuesta exitosa para que sut.send() no falle.
        // Esto es necesario porque observeRequests ahora solo configura el observador.
        let dummyData = Data() // Puede ser Data vacía si el test no la usa.
        let dummyResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        URLProtocolStub.stub(data: dummyData, response: dummyResponse, error: nil)

        let (sut, _) = makeSUT()
        do {
            // CHANGE: La llamada a send ahora debe ser para la URLRequest correcta
            _ = try await sut.send(URLRequest(url: url))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [exp], timeout: 1.0)
    }

    func test_send_whenSwiftTaskIsCancelled_throwsCancellationError() async {
        // Arrange
        let (sut, _) = makeSUT()

        URLProtocolStub.hangRequests = true
        URLProtocolStub.observeRequests { _ in } // Necesario para que el requestObserver no sea nil si así lo espera la lógica
        // o simplemente para asegurar un estado consistente.
        // Alternativamente, se puede quitar si no es estrictamente necesario para 'hangRequests'.

        let task = Task { () -> (Data, HTTPURLResponse) in
            try await sut.send(anyURLRequest())
        }

        // Act
        try? await Task.sleep(nanoseconds: 1_000_000) // 1 millisecond

        task.cancel()

        // Assert
        do {
            _ = try await task.value
            // CHANGE: Mensaje de XCTFail y tipo de error esperado
            XCTFail("Expected send to throw URLError with code .cancelled, but it succeeded or threw a different error.")
            // CHANGE: Tipo de error esperado y condición
        } catch let error as URLError where error.code == .cancelled {
            // This is the expected outcome: URLSession task was cancelled.
        } catch {
            // CHANGE: Mensaje de XCTFail y tipo de error esperado
            XCTFail("Expected send to throw URLError with code .cancelled, but threw \(error) instead.")
        }
    }

    func test_getFromURL_failsOnRequestError() async {
        let requestError = anyNSError()

        let receivedError = await resultErrorFor((data: nil, response: nil, error: requestError)) // Uses overload 1

        XCTAssertNotNil(receivedError)
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

        // CHANGE: Create SUT once outside the loop
        let (sut, _) = makeSUT()
        let timeout: TimeInterval = 1.0 // Define timeout

        for invalidCase in invalidCases {
            // CHANGE: Only stub the protocol for each case
            URLProtocolStub.stub(data: invalidCase.data, response: invalidCase.response, error: invalidCase.error)

            let request = URLRequest(url: anyURL(), timeoutInterval: timeout)
            var receivedError: Error?
            do {
                _ = try await sut.send(request)
            } catch {
                receivedError = error
            }

            XCTAssertNotNil(receivedError, "Expected error for case: \(invalidCase)", file: #filePath, line: #line)

            // Optional: Clean up stub after each case if necessary, though tearDown should handle it.
            // URLProtocolStub.removeStub()
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

    func test_complete_withError_atIndexOutOfBounds_whenNoRequestsMade() {
        let (_, client) = makeSUT() // client es HTTPClientSpy

        client.complete(with: anyNSError(), at: 0) // Intentar completar en el índice 0 cuando no hay tareas

        let expectation = XCTestExpectation(description: "Allow async client.complete to proceed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Pequeña demora para la cola del spy
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)

        XCTAssertEqual(client.messages, [.failure("Index 0 out of bounds (count: 0)")])
    }

    // MARK: - Helpers

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
            return .success((data, response))
        case let (_, .some(error)):
            return .failure(error)
        default:
            return .failure(anyNSError())
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
        return URLRequest(url: anyURL())
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func nonHTTPURLResponse() -> URLResponse {
        return URLResponse(
            url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
}
