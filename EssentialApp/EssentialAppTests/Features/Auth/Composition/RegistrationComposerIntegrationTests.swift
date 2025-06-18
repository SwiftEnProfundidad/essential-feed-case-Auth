import EssentialApp
import EssentialFeed
import SwiftUI
import UIKit
import XCTest

final class RegistrationComposerIntegrationTests: XCTestCase {
    @MainActor
    func test_registrationViewController_createsUIHostingControllerWithRegistrationView() {
        let sut = RegistrationComposer.registrationViewController()

        XCTAssertTrue(sut is UIHostingController<RegistrationView>, "Should create UIHostingController with RegistrationView")
    }

    @MainActor
    func test_registrationViewController_configuresViewModelWithDependencies() {
        let sut = RegistrationComposer.registrationViewController()
        let hostingController = sut as? UIHostingController<RegistrationView>

        XCTAssertNotNil(hostingController, "Should create UIHostingController")
        XCTAssertNotNil(hostingController?.rootView, "Should have RegistrationView configured")
    }

    @MainActor
    func test_registrationViewController_doesNotRetainMemoryLeaks() {
        weak var weakSUT: UIViewController?

        autoreleasepool {
            let sut = RegistrationComposer.registrationViewController()
            weakSUT = sut
        }

        XCTAssertNil(weakSUT, "RegistrationViewController should not have memory leaks")
    }
}
