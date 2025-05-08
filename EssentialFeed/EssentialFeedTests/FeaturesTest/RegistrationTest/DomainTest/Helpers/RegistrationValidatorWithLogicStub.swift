import EssentialFeed
import Foundation

final class RegistrationValidatorWithLogicStub: RegistrationValidatorProtocol {
	init() {}
	
	func validate(name: String, email: String, password: String) -> RegistrationValidationError? {
		if name.trimmingCharacters(in: .whitespaces).isEmpty {
			return .emptyName
		}
		
		if !email.contains("@") || !email.contains(".") {
			return .invalidEmail
		}
		
		if password.count < 8 {
			return .weakPassword
		}
		
		return nil
	}
}
