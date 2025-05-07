//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

public struct ResourceErrorViewModel {
	public let message: String?
	
	public init(message: String?) {
		self.message = message
	}
	
	public static var noError: ResourceErrorViewModel {
		return ResourceErrorViewModel(message: nil)
	}
	
	public static func error(message: String) -> ResourceErrorViewModel {
		return ResourceErrorViewModel(message: message)
	}
}
