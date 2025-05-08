//
// Copyright © 2025 Essential Developer. All rights reserved.
//

import Foundation

public protocol UserRegistrationAPI {
	func register(with data: UserRegistrationData) async -> Result<UserRegistrationResponse, UserRegistrationError>
}
