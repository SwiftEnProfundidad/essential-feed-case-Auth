import EssentialApp
import EssentialFeed
import SwiftUI
import UIKit
import XCTest

final class RegistrationComposerTests: XCTestCase {
    @MainActor
    func test_registrationViewController_createsUIHostingControllerWithRegistrationView() {
        let sut = RegistrationComposer.registrationViewController()

        XCTAssertTrue(sut is UIHostingController<RegistrationView>, "Should create UIHostingController with RegistrationView")
    }

    @MainActor
    func test_registrationViewController_configuresViewControllerCorrectly() {
        let sut = RegistrationComposer.registrationViewController()

        XCTAssertNotNil(sut, "Should create a view controller")
        XCTAssertTrue(sut is UIHostingController<RegistrationView>, "Should be UIHostingController with RegistrationView")
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
