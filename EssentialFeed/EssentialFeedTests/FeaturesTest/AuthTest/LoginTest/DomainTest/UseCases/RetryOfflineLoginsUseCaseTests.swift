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

    final class OfflineLoginStoreSpy: OfflineLoginStore {
        var stub_loadAll: [LoginCredentials] = []
        func loadAll() async -> [LoginCredentials] { stub_loadAll }
        func save(credentials _: LoginCredentials) async throws {}
        func delete(credentials _: LoginCredentials) async throws {}
    }

    final class LoginAPISpy: UserLoginAPI {
        private(set) var performedRequests: [LoginCredentials] = []
        func login(with credentials: LoginCredentials) async -> Result<LoginResponse, LoginError> {
            performedRequests.append(credentials)
            return .failure(.network) // Por defecto, para futuros tests
        }
    }
}
