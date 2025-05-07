import Foundation
import XCTest
import EssentialFeed

final class HTTPClientSpy: HTTPClient, @unchecked Sendable {
	deinit {
		let pending = queue.sync { tasks.filter { !$0.isCompleted } }
		
		if !pending.isEmpty {
			let msg = "[HTTPClientSpy] WARNING: There are \(pending.count) tasks with uncompleted continuations on deinit."
			XCTFail(msg, file: #filePath, line: #line)
		} else {
		}
		
	}
	
	struct Task: Identifiable {
		let id = UUID()
		let request: URLRequest
		var completion: (Result<(Data, HTTPURLResponse), Error>) -> Void
		fileprivate(set) var isCompleted = false
	}
	
	// --- Propiedades públicas para inspección en tests ---
	public var requests: [URLRequest] {
		queue.sync { _requests }
	}
	
	public var requestedHTTPMethods: [String] {
		queue.sync { _requests.map { $0.httpMethod ?? "" } }
	}
	
	public var requestedHeaders: [[String: String]] {
		queue.sync { _requests.map { $0.allHTTPHeaderFields ?? [:] } }
	}
	
	private var _requests = [URLRequest]()
	fileprivate var tasks = [Task]()
	private var _messages = [Message]()
	fileprivate let queue = DispatchQueue(
		label: "com.essentialdeveloper.HTTPClientSpy.queue",
		attributes: .concurrent
	)
	
	enum Message: Equatable {
		case failure(String)
		case success
	}
	
	public var messages: [Message] {
		queue.sync { _messages }
		
	}
	
	func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
		queue.sync(flags: .barrier) {
			_requests.append(request)
			let task = Task(request: request, completion: { _ in })
			tasks.append(task)
		}
		
		return try await withCheckedThrowingContinuation { [weak self] continuation in
			self?.queue.async(flags: .barrier) {
				guard let self = self else { return }
				
				let index = self.tasks.firstIndex(where: { $0.request == request }) ?? 0
				if self.tasks[index].isCompleted {
					let msg = "[HTTPClientSpy] ERROR: Attempting to assign continuation to an already completed task at index \(index)."
					XCTFail(msg, file: #filePath, line: #line)
					continuation.resume(throwing: NSError(domain: "HTTPClientSpy", code: -9999, userInfo: [NSLocalizedDescriptionKey: msg]))
					return
				}
				
				self.tasks[index].completion = { result in
					continuation.resume(with: result)
				}
				
			}
			
		}
		
	}
	
	func complete(with error: Error, at index: Int = 0) {
		queue.async(flags: .barrier) {
			guard self.tasks.indices.contains(index) else {
				let message = "Index \(index) out of bounds (count: \(self.tasks.count))"
				self._messages.append(.failure(message))
				return
			}
			
			guard !self.tasks[index].isCompleted else {
				let msg = "[HTTPClientSpy] WARNING: Attempt to complete an already completed task at index \(index) (error)."
				assertionFailure(msg)
				return
			}
			
			self.tasks[index].isCompleted = true
			let completion = self.tasks[index].completion
			self.tasks[index].completion = { _ in }
			
			completion(.failure(error))
			self._messages.append(.success)
		}
	}
	
	func complete(with data: Data, response: HTTPURLResponse, at index: Int = 0) {
		queue.async(flags: .barrier) {
			guard self.tasks.indices.contains(index) else {
				let message = "Index \(index) out of bounds (count: \(self.tasks.count))"
				self._messages.append(.failure(message))
				return
			}
			
			guard !self.tasks[index].isCompleted else {
				let msg = "[HTTPClientSpy] WARNING: Attempt to complete an already completed task at index \(index) (success)."
				assertionFailure(msg)
				return
			}
			
			self.tasks[index].isCompleted = true
			let completion = self.tasks[index].completion
			self.tasks[index].completion = { _ in }
			
			completion(.success((data, response)))
			self._messages.append(.success)
		}
	}
	
}

// MARK: - Dummy-like extension

extension HTTPClientSpy {
	/// Completes all pending requests with a dummy error, simulating a dummy client.
	public func failAllPendingRequestsAsDummy() {
		let error = NSError(
			domain: "HTTPClientDummy",
			code: -1,
			userInfo: [NSLocalizedDescriptionKey: "Dummy implementation should not be called in tests"]
		)
		let indices: [Int] = queue.sync { tasks.enumerated().filter { !$0.element.isCompleted }.map { $0.offset } }
		for index in indices {
			complete(with: error, at: index)
		}
	}
}
