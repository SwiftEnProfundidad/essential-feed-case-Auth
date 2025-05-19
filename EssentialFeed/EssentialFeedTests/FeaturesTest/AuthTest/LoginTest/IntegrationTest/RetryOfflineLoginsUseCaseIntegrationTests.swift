import EssentialFeed
import XCTest

final class RetryOfflineLoginsUseCaseIntegrationTests: XCTestCase {
    func test_execute_endToEnd_flow_retriesStoredCredentials_andCleansUpStore() async {
        let (sut, offlineStore, loginAPI) = makeSUT()

        let credentials1 = LoginCredentials(email: "e2e_a@a.com", password: "pw1")
        let credentials2 = LoginCredentials(email: "e2e_b@b.com", password: "pw2")
        try? await offlineStore.save(credentials: credentials1)
        try? await offlineStore.save(credentials: credentials2)
        loginAPI.stubbedResults = [
            .success(LoginResponse(token: "OKTOKEN")),
            .failure(.invalidCredentials)
        ]

        let results = await sut.execute()

        XCTAssertEqual(results.count, 2)
        if case .success = results[0] {} else { XCTFail("Expected success for first credentials") }
        if case let .failure(err) = results[1] { XCTAssertEqual(err, .invalidCredentials) } else { XCTFail("Expected failure for second credentials") }
        let remaining = await offlineStore.loadAll()
        XCTAssertEqual(remaining, [credentials2], "Only failure remains in offline store after retry")
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
