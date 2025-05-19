@testable import EssentialFeed
import XCTest

final class RetryOfflineLoginsUseCaseTests: XCTestCase {
    func test_execute_whenNoPendingRequests_returnsEmptyResultArray_andDoesNotCallLoginAPI() async {
        let (sut, offlineStore, loginAPI) = makeSUT()
        offlineStore.stub_loadAll = []

        let results = await sut.execute()

        XCTAssertEqual(results.count, 0)
        XCTAssertTrue(loginAPI.performedRequests.isEmpty)
    }

    func test_execute_whenPendingRequests_callsLoginAPIWithEach_andReturnsResults() async {
        let (sut, offlineStore, loginAPI) = makeSUT()
        let credentials1 = LoginCredentials(email: "a@a.com", password: "pw1")
        let credentials2 = LoginCredentials(email: "b@b.com", password: "pw2")
        offlineStore.stub_loadAll = [credentials1, credentials2]

        loginAPI.stubbedResults = [
            .success(LoginResponse(token: "token1")),
            .failure(.invalidCredentials)
        ]

        let results = await sut.execute()

        XCTAssertEqual(loginAPI.performedRequests, [credentials1, credentials2])
        XCTAssertEqual(results.count, 2)

        if case .success = results[0] {
        } else {
            XCTFail("Expected .success for first result")
        }

        if case let .failure(err) = results[1] {
            XCTAssertEqual(err, .invalidCredentials)
        } else {
            XCTFail("Expected .failure(.invalidCredentials) for second result")
        }
    }

    func test_execute_onSuccess_deletesRequestFromStore_onFailure_doesNotDelete() async {
        let (sut, offlineStore, loginAPI) = makeSUT()
        let credentials1 = LoginCredentials(email: "x@a.com", password: "a")
        let credentials2 = LoginCredentials(email: "y@b.com", password: "b")
        offlineStore.stub_loadAll = [credentials1, credentials2]

        loginAPI.stubbedResults = [
            .success(LoginResponse(token: "tokenX")),
            .failure(.invalidCredentials)
        ]

        var deleted: [LoginCredentials] = []
        offlineStore.onDelete = { cred in deleted.append(cred) }

        _ = await sut.execute()

        XCTAssertEqual(deleted, [credentials1], "Should delete only success")
    }

    // MARK: - Helpers & Spies

    private func makeSUT() -> (sut: RetryOfflineLoginsUseCase, offlineStore: OfflineLoginStoreSpy, loginAPI: LoginAPISpy) {
        let offlineStore = OfflineLoginStoreSpy()
        let loginAPI = LoginAPISpy()
        let sut = RetryOfflineLoginsUseCase(offlineStore: offlineStore, loginAPI: loginAPI)
        trackForMemoryLeaks(offlineStore)
        trackForMemoryLeaks(loginAPI)
        trackForMemoryLeaks(sut)
        return (sut, offlineStore, loginAPI)
    }

    final class OfflineLoginStoreSpy: OfflineLoginLoading, OfflineLoginDeleting, OfflineLoginStoring {
        var stub_loadAll: [LoginCredentials] = []
        func loadAll() async -> [LoginCredentials] { stub_loadAll }

        var onDelete: ((LoginCredentials) -> Void)?
        func delete(credentials: LoginCredentials) async throws {
            onDelete?(credentials)
        }

        func save(credentials _: LoginCredentials) async throws {}
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
