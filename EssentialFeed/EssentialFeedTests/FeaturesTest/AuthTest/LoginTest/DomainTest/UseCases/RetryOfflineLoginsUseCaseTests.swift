import EssentialFeed
import XCTest

final class RetryOfflineLoginsUseCaseTests: XCTestCase {
    func test_execute_whenNoPendingRequests_returnsEmptyArray() async throws {
        let (sut, offlineStore, loginAPI) = makeSUT()
        offlineStore.stubLoadAll(with: [])

        let results = try await sut.execute()

        XCTAssertEqual(results.count, 0, "Should return empty array when no pending requests")
        XCTAssertTrue(loginAPI.performedRequests.isEmpty, "Should not call login API when no pending requests")
    }

    func test_execute_whenPendingRequests_returnsResultsWithSameCredentials() async throws {
        let (sut, offlineStore, loginAPI) = makeSUT()
        let credentials1 = LoginCredentials(email: "user1@test.com", password: "password1")
        let credentials2 = LoginCredentials(email: "user2@test.com", password: "password2")
        offlineStore.stubLoadAll(with: [credentials1, credentials2])

        loginAPI.stubbedResults = [
            .success(LoginResponse(
                user: User(name: "Test User 1", email: credentials1.email),
                token: Token(accessToken: "token1", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
            )),
            .failure(.invalidCredentials)
        ]

        let results = try await sut.execute()

        XCTAssertEqual(results.count, 2, "Should return result for each request")
        XCTAssertEqual(results[0].credentials, credentials1, "First result should contain first credentials")
        XCTAssertEqual(results[1].credentials, credentials2, "Second result should contain second credentials")
        XCTAssertEqual(loginAPI.performedRequests, [credentials1, credentials2], "Should call login API for all credentials")
    }

    func test_execute_whenLoginSucceeds_resultContainsSuccessfulLoginResponse() async throws {
        let (sut, offlineStore, loginAPI) = makeSUT()
        let credentials = LoginCredentials(email: "user@test.com", password: "password")
        offlineStore.stubLoadAll(with: [credentials])
        let expectedResponse = LoginResponse(user: User(name: "Test User", email: "user@test.com"), token: Token(accessToken: "success-token", expiry: Date().addingTimeInterval(3600), refreshToken: nil))
        loginAPI.stubbedResults = [.success(expectedResponse)]

        let results = try await sut.execute()

        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertTrue(results[0].isSuccessful, "Result should be marked as successful")

        if case let .success(response) = results[0].loginResult {
            XCTAssertEqual(response.token.accessToken, "success-token", "Should contain the login response from API")
        } else {
            XCTFail("Expected successful login result")
        }
    }

    func test_execute_whenLoginFails_resultContainsFailureError() async throws {
        let (sut, offlineStore, loginAPI) = makeSUT()
        let credentials = LoginCredentials(email: "user@test.com", password: "wrong-password")
        offlineStore.stubLoadAll(with: [credentials])
        loginAPI.stubbedResults = [.failure(.invalidCredentials)]

        let results = try await sut.execute()

        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertFalse(results[0].isSuccessful, "Result should be marked as failed")

        if case let .failure(error) = results[0].loginResult {
            XCTAssertEqual(error, .invalidCredentials, "Should contain the login error from API")
        } else {
            XCTFail("Expected failed login result")
        }
    }

    func test_execute_withMixedResults_returnsBothSuccessAndFailureResults() async throws {
        let (sut, offlineStore, loginAPI) = makeSUT()
        let credentials1 = LoginCredentials(email: "success@test.com", password: "password")
        let credentials2 = LoginCredentials(email: "fail@test.com", password: "password")
        let credentials3 = LoginCredentials(email: "success2@test.com", password: "password")

        offlineStore.stubLoadAll(with: [credentials1, credentials2, credentials3])
        loginAPI.stubbedResults = [
            .success(LoginResponse(
                user: User(name: "Success User 1", email: credentials1.email),
                token: Token(accessToken: "token1", expiry: Date().addingTimeInterval(3600), refreshToken: nil)
            )),
            .failure(.network),
            .success(LoginResponse(user: User(name: "Success User 2", email: "success2@test.com"), token: Token(accessToken: "token3", expiry: Date().addingTimeInterval(3600), refreshToken: nil)))
        ]

        let results = try await sut.execute()

        XCTAssertEqual(results.count, 3, "Should return three results")
        XCTAssertTrue(results[0].isSuccessful, "First should be successful")
        XCTAssertFalse(results[1].isSuccessful, "Second should be failed")
        XCTAssertTrue(results[2].isSuccessful, "Third should be successful")
        XCTAssertEqual(loginAPI.performedRequests, [credentials1, credentials2, credentials3], "Should call API for all")
    }

    // MARK: - Helpers

    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: RetryOfflineLoginsUseCase,
        offlineStore: OfflineLoginStoreSpy,
        loginAPI: LoginAPISpy
    ) {
        let offlineStore = OfflineLoginStoreSpy()
        let loginAPI = LoginAPISpy()
        let sut = RetryOfflineLoginsUseCase(offlineStore: offlineStore, loginAPI: loginAPI)

        trackForMemoryLeaks(offlineStore, file: file, line: line)
        trackForMemoryLeaks(loginAPI, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, offlineStore, loginAPI)
    }

    final class LoginAPISpy: UserLoginAPI {
        private(set) var performedRequests: [LoginCredentials] = []
        var stubbedResults: [Result<LoginResponse, LoginError>] = []

        func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
            performedRequests.append(credentials)
            if !stubbedResults.isEmpty {
                return stubbedResults.removeFirst()
            }
            return .failure(.network)
        }
    }
}
