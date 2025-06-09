import EssentialFeed
import XCTest

final class RetryOfflineLoginsUseCaseIntegrationTests: XCTestCase {
    func test_execute_endToEnd_flow_retriesStoredCredentials_returnsResults() async throws {
        let (sut, offlineStore, loginAPI) = makeSUT()

        let credentials1 = LoginCredentials(email: "e2e_a@a.com", password: "pw1")
        let credentials2 = LoginCredentials(email: "e2e_b@b.com", password: "pw2")
        try? await offlineStore.save(credentials: credentials1)
        try? await offlineStore.save(credentials: credentials2)
        loginAPI.stubbedResults = [
            .success(LoginResponse(token: "OKTOKEN")),
            .failure(.invalidCredentials)
        ]

        let results = try await sut.execute()

        XCTAssertEqual(results.count, 2, "Should return result for each stored credential")
        XCTAssertEqual(loginAPI.performedRequests, [credentials1, credentials2], "Should call login API for all stored credentials")

        XCTAssertTrue(results[0].isSuccessful, "First login retry should be successful")
        XCTAssertEqual(results[0].credentials, credentials1, "First result should contain first credentials")
        if case let .success(response) = results[0].loginResult {
            XCTAssertEqual(response.token, "OKTOKEN", "Should contain the expected token")
        } else {
            XCTFail("Expected successful login result for first credentials")
        }

        XCTAssertFalse(results[1].isSuccessful, "Second login retry should fail")
        XCTAssertEqual(results[1].credentials, credentials2, "Second result should contain second credentials")
        if case let .failure(error) = results[1].loginResult {
            XCTAssertEqual(error, .invalidCredentials, "Should contain the expected error")
        } else {
            XCTFail("Expected failed login result for second credentials")
        }

        let remaining = await offlineStore.loadAll()
        XCTAssertEqual(remaining, [credentials1, credentials2], "Use Case should not modify the store (it's pure)")
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: RetryOfflineLoginsUseCase, offlineStore: InMemoryOfflineLoginStore, loginAPI: FakeUserLoginAPI) {
        let offlineStore = InMemoryOfflineLoginStore()
        let loginAPI = FakeUserLoginAPI()
        let sut = RetryOfflineLoginsUseCase(offlineStore: offlineStore, loginAPI: loginAPI)
        trackForMemoryLeaks(offlineStore, file: file, line: line)
        trackForMemoryLeaks(loginAPI, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, offlineStore, loginAPI)
    }
}

final class InMemoryOfflineLoginStore: OfflineLoginStore {
    private var store: [LoginCredentials] = []
    func loadAll() async -> [LoginCredentials] { store }
    func save(credentials: LoginCredentials) async throws { store.append(credentials) }
    func delete(credentials: LoginCredentials) async throws { store.removeAll { $0 == credentials } }
}

final class FakeUserLoginAPI: UserLoginAPI {
    var stubbedResults: [Result<LoginResponse, LoginError>] = []
    private(set) var performedRequests: [LoginCredentials] = []
    func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
        performedRequests.append(credentials)
        if !stubbedResults.isEmpty { return stubbedResults.removeFirst() }
        return .failure(.network)
    }
}
