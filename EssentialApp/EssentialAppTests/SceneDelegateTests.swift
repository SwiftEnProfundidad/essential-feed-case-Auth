//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import XCTest
@testable import EssentialApp
import EssentialFeediOS
import SwiftUI
import EssentialApp

class SceneDelegateTests: XCTestCase {
	
	func test_configureWindow_setsWindowAsKeyAndVisible() {
		let window = UIWindowSpy()
		let sut = SceneDelegate()
		sut.window = window
		
		sut.configureWindow()
		
		XCTAssertEqual(window.makeKeyAndVisibleCallCount, 1, "Expected to make window key and visible")
	}
	
	func test_configureWindow_configuresRootViewController() {
		let sut = SceneDelegate()
		sut.window = UIWindowSpy()
		
		sut.configureWindow()
		
		let root = sut.window?.rootViewController
		if let nav = root as? UINavigationController {
			let topController = nav.topViewController
			XCTAssertTrue(
				topController is ListViewController,
				"Expected a feed controller as top view controller, got \(String(describing: topController)) instead"
			)
		} else if let hosting = root,
							String(describing: type(of: hosting)).contains("UIHostingController") {
			XCTAssertTrue(
				String(describing: type(of: hosting)).contains("LoginView"),
				"Expected a SwiftUI LoginView as root in UIHostingController")
		} else {
			XCTFail("Unexpected rootViewController type: \(String(describing: root))")
		}
	}
	
	private class UIWindowSpy: UIWindow {
		var makeKeyAndVisibleCallCount = 0
		
		override func makeKeyAndVisible() {
			makeKeyAndVisibleCallCount = 1
		}
	}
	
}
