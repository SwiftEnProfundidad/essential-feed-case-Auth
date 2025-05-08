
import Foundation
import EssentialFeed

final class OfflineRegistrationStoreSpy: OfflineRegistrationStore {
	enum Message: Equatable {
		case save(UserRegistrationData)
	}
	
	private(set) var messages = [Message]()
	var saveError: Error?
	
	func save(_ data: UserRegistrationData) async throws {
		if let error = saveError {
			throw error
		}
		messages.append(.save(data))
	}
}
