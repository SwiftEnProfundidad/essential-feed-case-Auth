
import EssentialFeed
import Foundation
import XCTest

final class HTTPClientSpy: HTTPClient, @unchecked Sendable {
    deinit {
        let pending = queue.sync { tasks.filter { !$0.isCompleted } }

        if !pending.isEmpty {
            let msg = "[HTTPClientSpy] WARNING: There are \(pending.count) tasks with uncompleted continuations on deinit."
            XCTFail(msg, file: #filePath, line: #line)
        } else {}
    }

    struct Task: Identifiable {
        let id = UUID()
        let request: URLRequest
        var completion: (Result<(Data, HTTPURLResponse), Error>) -> Void
        var isCompleted: Bool = false
    }

    public var requests: [URLRequest] {
        queue.sync { _requests }
    }

    public var requestedHTTPMethods: [String] {
        queue.sync { _requests.map { $0.httpMethod ?? "" } }
    }

    public var requestedHeaders: [[String: String]] {
        queue.sync { _requests.map { $0.allHTTPHeaderFields ?? [:] } }
    }

    public var onRequest: ((URLRequest) -> Void)?
    private var _requests: [URLRequest] = .init()
    private var tasks: [Task] = .init()
    private var _messages: [Message] = .init()
    private let queue: DispatchQueue = .init(
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
            onRequest?(request)
            let task = Task(request: request, completion: { _ in })
            tasks.append(task)
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.queue.async(flags: .barrier) {
                guard let self else { return }

                var taskIndexToAssignContinuation: Int?
                for (index, task) in self.tasks.enumerated().reversed() {
                    if task.request == request, !task.isCompleted {
                        taskIndexToAssignContinuation = index
                        break
                    }
                }
                let indexToUse = taskIndexToAssignContinuation ?? (self.tasks.count - 1)

                guard self.tasks.indices.contains(indexToUse) else {
                    let msg = "[HTTPClientSpy] ERROR: Index \(indexToUse) out of bounds for assigning continuation."
                    XCTFail(msg, file: #filePath, line: #line)
                    continuation.resume(throwing: NSError(domain: "HTTPClientSpy", code: -9998, userInfo: [NSLocalizedDescriptionKey: msg]))
                    return
                }

                if self.tasks[indexToUse].isCompleted {
                    let msg = "[HTTPClientSpy] ERROR: Attempting to assign continuation to an already completed task at index \(indexToUse)."
                    XCTFail(msg, file: #filePath, line: #line)
                    continuation.resume(throwing: NSError(domain: "HTTPClientSpy", code: -9999, userInfo: [NSLocalizedDescriptionKey: msg]))
                    return
                }

                self.tasks[indexToUse].completion = { result in
                    continuation.resume(with: result)
                }
            }
        }
    }

    func complete(with error: Error, at optionalIndex: Int? = nil) {
        queue.async(flags: .barrier) {
            let indexToComplete: Int
            if let explicitIndex = optionalIndex {
                guard self.tasks.indices.contains(explicitIndex) else {
                    let message = "Index \(explicitIndex) out of bounds (count: \(self.tasks.count))"
                    self._messages.append(.failure(message))
                    return
                }
                indexToComplete = explicitIndex
            } else {
                guard let firstUncompletedIndex = self.tasks.firstIndex(where: { !$0.isCompleted }) else {
                    let msg = "[HTTPClientSpy] WARNING: No uncompleted task found to complete with error."
                    self._messages.append(.failure(msg))
                    return
                }
                indexToComplete = firstUncompletedIndex
            }

            guard !self.tasks[indexToComplete].isCompleted else {
                let msg = "[HTTPClientSpy] WARNING: Attempt to complete an already completed task at index \(indexToComplete) (error)."
                assertionFailure(msg)
                return
            }

            self.tasks[indexToComplete].isCompleted = true
            let completion = self.tasks[indexToComplete].completion
            self.tasks[indexToComplete].completion = { _ in }

            completion(.failure(error))
            self._messages.append(.success)
        }
    }

    func complete(with data: Data, response: HTTPURLResponse, at optionalIndex: Int? = nil) {
        queue.async(flags: .barrier) {
            let indexToComplete: Int
            if let explicitIndex = optionalIndex {
                guard self.tasks.indices.contains(explicitIndex) else {
                    let message = "Index \(explicitIndex) out of bounds (count: \(self.tasks.count))"
                    self._messages.append(.failure(message))
                    return
                }
                indexToComplete = explicitIndex
            } else {
                guard let firstUncompletedIndex = self.tasks.firstIndex(where: { !$0.isCompleted }) else {
                    let msg = "[HTTPClientSpy] WARNING: No uncompleted task found to complete with data."
                    self._messages.append(.failure(msg))
                    return
                }
                indexToComplete = firstUncompletedIndex
            }

            guard !self.tasks[indexToComplete].isCompleted else {
                let msg = "[HTTPClientSpy] WARNING: Attempt to complete an already completed task at index \(indexToComplete) (success)."
                assertionFailure(msg)
                return
            }

            self.tasks[indexToComplete].isCompleted = true
            let completion = self.tasks[indexToComplete].completion
            self.tasks[indexToComplete].completion = { _ in }

            completion(.success((data, response)))
            self._messages.append(.success)
        }
    }
}

// MARK: - Dummy-like extension

extension HTTPClientSpy {
    public func failAllPendingRequestsAsDummy() {
        let error = NSError(
            domain: "HTTPClientDummy",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Dummy implementation should not be called in tests"]
        )
        let indices: [Int] = queue.sync { tasks.enumerated().filter { !$0.element.isCompleted }.map(\.offset) }
        for index in indices {
            complete(with: error, at: index)
        }
    }
}
