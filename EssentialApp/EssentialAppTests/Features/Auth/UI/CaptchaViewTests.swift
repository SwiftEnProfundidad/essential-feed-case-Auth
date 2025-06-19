import EssentialApp
import SwiftUI
import XCTest

final class CaptchaViewTests: XCTestCase {
    func test_init_setsCorrectProperties() {
        let tokenValue: String? = "test-token"
        let tokenBinding = Binding.constant(tokenValue)
        let (sut, spy) = makeSUT(token: tokenBinding)

        XCTAssertEqual(sut.token, tokenValue, "Expected token to match provided binding value")
        XCTAssertTrue(sut.isVisible, "Expected isVisible to default to true")
        trackForMemoryLeaks(spy)
    }

    func test_onTokenReceived_callsProvidedCallback() {
        let expectedToken = "received-token"
        let (_, spy) = makeSUT()

        spy.simulateTokenReceived(expectedToken)

        XCTAssertEqual(
            spy.receivedTokens, [expectedToken],
            "Expected onTokenReceived callback to be called with correct token"
        )
    }

    func test_isVisible_false_hidesView() {
        let (sut, spy) = makeSUT(isVisible: false)

        XCTAssertFalse(sut.isVisible, "Expected view to be hidden when isVisible is false")
        trackForMemoryLeaks(spy)
    }

    func test_tokenBinding_updatesCorrectly() {
        let initialTokenValue: String? = "initial-token"
        let updatedTokenValue: String? = "updated-token"

        var tokenState = initialTokenValue
        let tokenBinding = Binding<String?>(
            get: { tokenState },
            set: { tokenState = $0 }
        )

        let (sut, spy) = makeSUT(token: tokenBinding)

        XCTAssertEqual(sut.token, initialTokenValue, "Expected initial token to be set correctly")

        tokenBinding.wrappedValue = updatedTokenValue

        XCTAssertEqual(sut.token, updatedTokenValue, "Expected token to update when binding changes")
        trackForMemoryLeaks(spy)
    }

    private func makeSUT(
        token: Binding<String?> = .constant(nil),
        isVisible: Bool = true,
        file _: StaticString = #filePath,
        line _: UInt = #line
    ) -> (CaptchaView, CaptchaViewSpy) {
        let spy = CaptchaViewSpy()
        let sut = CaptchaView(
            token: token,
            onTokenReceived: spy.onTokenReceived,
            isVisible: isVisible
        )

        return (sut, spy)
    }
}

private final class CaptchaViewSpy {
    private(set) var receivedTokens: [String] = []

    func onTokenReceived(token: String) {
        receivedTokens.append(token)
    }

    func simulateTokenReceived(_ token: String) {
        onTokenReceived(token: token)
    }
}
