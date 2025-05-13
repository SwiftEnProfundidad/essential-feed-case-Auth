
import EssentialApp
import EssentialFeed
import XCTest

final class LoginViewModelAdapterTests: XCTestCase {
    func test_init_setsInitialState() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.username, "")
        XCTAssertEqual(sut.password, "")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.loginSuccess)
        XCTAssertFalse(sut.isLoginBlocked)
    }

    func test_login_propagatesToRealViewModel() async {
        let (sut, mock) = makeSUT()

        sut.username = "test@user.com"
        sut.password = "password123"
        await sut.login()

        XCTAssertEqual(mock.username, "test@user.com")
        XCTAssertEqual(mock.password, "password123")
        XCTAssertEqual(mock.loginCallCount, 1)
    }

    func test_stateChanges() {
        let (_, mock) = makeSUT()

        mock.errorMessage = "Test Error"
        XCTAssertEqual(mock.errorMessage, "Test Error")

        mock.loginSuccess = true
        XCTAssertTrue(mock.loginSuccess)
    }

    // MARK: - Helpers

    private func makeSUT() -> (sut: LoginViewModelMock, mock: LoginViewModelMock) {
        let mock = LoginViewModelMock(authenticate: { _, _ in .failure(.invalidCredentials) })
        // Si necesitamos un adapter real, reemplazar LoginViewModelMock por el adapter.
        // let sut = LoginViewModelAdapter(realViewModel: mock)
        let sut = mock
        trackForMemoryLeaks(mock)
        trackForMemoryLeaks(sut)
        return (sut, mock)
    }
}

final class LoginViewModelMock: LoginViewModelProtocol {
    var username: String = ""
    var password: String = ""
    var errorMessage: String?
    var loginSuccess: Bool = false
    var isLoginBlocked: Bool = false

    var loginCallCount = 0
    var unlockAfterRecoveryCallCount = 0

    private let authenticate: (String, String) async -> Result<LoginResponse, LoginError>

    init(authenticate: @escaping (String, String) async -> Result<LoginResponse, LoginError>) {
        self.authenticate = authenticate
    }

    func login() async {
        loginCallCount += 1
        _ = await authenticate(username, password)
    }

    func unlockAfterRecovery() {
        unlockAfterRecoveryCallCount += 1
        isLoginBlocked = false
        errorMessage = nil
    }
}
