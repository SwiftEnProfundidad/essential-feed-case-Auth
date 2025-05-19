import EssentialFeed
import XCTest

final class AuthUseCaseTests: XCTestCase {
    func test_init_doesNotPerformAnyRequest() async {
        let (_, spy) = makeSUT()
        XCTAssertFalse(spy.wasCalled)
    }

    func test_execute_performsAuthentication() async {
        let (sut, spy) = makeSUT()
        let email = "test@user.com"
        let password = "password123"

        _ = await sut.execute(username: email, password: password)

        XCTAssertEqual(spy.messages.count, 1)
        XCTAssertEqual(spy.messages[0].email, email)
        XCTAssertEqual(spy.messages[0].password, password)
    }

    func test_execute_returnsSuccessOnSuccessfulAuthentication() async {
        let expectedResponse = LoginResponse(token: "a-token")
        let (sut, spy) = makeSUT()
        spy.stubbedResult = .success(expectedResponse)

        let result = await sut.execute(username: "any@test.com", password: "any")

        if case let .success(response) = result {
            XCTAssertEqual(response, expectedResponse)
        } else {
            XCTFail("Expected success, got \(result)")
        }
    }

    func test_execute_returnsFailureOnFailedAuthentication() async {
        let expectedError = LoginError.invalidCredentials
        let (sut, spy) = makeSUT()
        spy.stubbedResult = .failure(expectedError)

        let result = await sut.execute(username: "any@test.com", password: "any")

        if case let .failure(error) = result {
            XCTAssertEqual(error, expectedError)
        } else {
            XCTFail("Expected failure, got \(result)")
        }
    }

    func test_execute_savesRequestOnNetworkError() async {
        let store = InMemoryPendingRequestStore<LoginRequest>()
        let requestStore = AnyLoginRequestStore(store)
        let (sut, spy) = makeSUT(requestStore: requestStore)
        spy.stubbedResult = .failure(.network)

        let email = "test@user.com"
        let password = "password123"
        _ = await sut.execute(username: email, password: password)

        let savedRequests = store.loadAll()
        XCTAssertEqual(savedRequests.count, 1)
        XCTAssertEqual(savedRequests.first?.username, email)
        XCTAssertEqual(savedRequests.first?.password, password)
    }

    func test_execute_doesNotSaveRequestOnNonNetworkError() async {
        let store = InMemoryPendingRequestStore<LoginRequest>()
        let requestStore = AnyLoginRequestStore(store)
        let (sut, spy) = makeSUT(requestStore: requestStore)
        spy.stubbedResult = .failure(.invalidCredentials)

        _ = await sut.execute(username: "any@test.com", password: "any")

        XCTAssertTrue(store.loadAll().isEmpty)
    }

    // MARK: - Helpers

    private func makeSUT(
        requestStore: AnyLoginRequestStore? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: AuthUseCase, spy: AuthAPISpy) {
        let spy = AuthAPISpy()
        let sut = AuthUseCase(
            authenticate: { email, password in
                await spy.login(with: LoginCredentials(email: email, password: password))
            },
            pendingRequestStore: requestStore
        )

        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(spy, file: file, line: line)

        return (sut, spy)
    }
}
