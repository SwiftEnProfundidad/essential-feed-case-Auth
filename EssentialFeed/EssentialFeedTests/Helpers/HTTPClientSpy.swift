import EssentialFeed
import Foundation
import XCTest

public actor HTTPClientSpy: HTTPClient {
    private struct TaskState: Identifiable {
        let id: UUID
        let request: URLRequest
        var isCompleted: Bool
    }

    private var activeTasks: [TaskState]
    private var loggedRequests: [URLRequest]
    private var loggedMessages: [Message]
    private var _sendResultsQueue: [Result<(Data, HTTPURLResponse), Error>] = []
    private var continuations: [UUID: CheckedContinuation<(Data, HTTPURLResponse), Error>] = [:]

    public enum Message: Equatable {
        case requestSent(URLRequest)
        case completionSuccess(UUID, URLRequest)
        case completionFailure(UUID, URLRequest, String)
        case spyError(String)
        case stubbedResponseUsed(URLRequest)
    }

    public init() {
        self.activeTasks = []
        self.loggedRequests = []
        self.loggedMessages = []
    }

    public var requests: [URLRequest] {
        loggedRequests
    }

    public var messages: [Message] {
        loggedMessages
    }

    public func getSendResultsQueueCount() -> Int {
        _sendResultsQueue.count
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let taskID = UUID()
        loggedRequests.append(request)
        loggedMessages.append(.requestSent(request))

        if !_sendResultsQueue.isEmpty {
            let result = _sendResultsQueue.removeFirst()
            loggedMessages.append(.stubbedResponseUsed(request))
            switch result {
            case .success(let (data, response)):
                loggedMessages.append(.completionSuccess(taskID, request))
                return (data, response)
            case let .failure(error):
                loggedMessages.append(.completionFailure(taskID, request, error.localizedDescription))
                throw error
            }
        }

        let newTaskState = TaskState(id: taskID, request: request, isCompleted: false)
        self.activeTasks.append(newTaskState)

        return try await withCheckedThrowingContinuation { continuation in
            if self.activeTasks.firstIndex(where: { $0.id == taskID && !$0.isCompleted }) != nil {
                self.continuations[taskID] = continuation
            } else {
                continuation.resume(throwing: NSError(domain: "HTTPClientSpy", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Failed to store continuation for task ID \(taskID). Task not found or already completed."]))
            }
        }
    }

    public func stubNextSend(result: Result<(Data, HTTPURLResponse), Error>) {
        _sendResultsQueue.append(result)
    }

    private func findTaskState(withID id: UUID? = nil, at optionalIndex: Int? = nil) -> (index: Int, task: TaskState)? {
        var taskIndexToComplete: Int?

        if let explicitID = id {
            taskIndexToComplete = self.activeTasks.firstIndex { $0.id == explicitID && !$0.isCompleted }
        } else if let explicitIndex = optionalIndex, self.activeTasks.indices.contains(explicitIndex), !self.activeTasks[explicitIndex].isCompleted {
            taskIndexToComplete = explicitIndex
        } else if optionalIndex == nil, id == nil {
            taskIndexToComplete = self.activeTasks.firstIndex { !$0.isCompleted }
        }

        guard let index = taskIndexToComplete, self.activeTasks.indices.contains(index) else {
            let idString = id?.uuidString ?? "N/A"
            let indexString = optionalIndex != nil ? String(describing: optionalIndex!) : "first available"
            let message = "[HTTPClientSpy] ERROR: Task not found or already completed for completion. ID: \(idString), Index: \(indexString)."
            loggedMessages.append(.spyError(message))
            return nil
        }

        return (index, self.activeTasks[index])
    }

    public func complete(with error: Error, at optionalIndex: Int? = nil) {
        guard let (taskIndex, task) = findTaskState(at: optionalIndex) else {
            if optionalIndex == 0, activeTasks.isEmpty {
                let message = "[HTTPClientSpy] ERROR: Attempted to complete task at index 0, but no tasks are active."
                loggedMessages.append(.spyError(message))
            }
            return
        }

        guard let continuation = continuations.removeValue(forKey: task.id) else {
            loggedMessages.append(.spyError("[HTTPClientSpy] ERROR: No continuation found for task ID \(task.id) to complete with error."))
            activeTasks[taskIndex].isCompleted = true
            return
        }

        continuation.resume(throwing: error)
        activeTasks[taskIndex].isCompleted = true
        loggedMessages.append(.completionFailure(task.id, task.request, error.localizedDescription))
    }

    public func complete(with error: Error, forTaskID id: UUID) {
        guard let (taskIndex, task) = findTaskState(withID: id) else { return }

        guard let continuation = continuations.removeValue(forKey: task.id) else {
            loggedMessages.append(.spyError("[HTTPClientSpy] ERROR: No continuation found for task ID \(task.id) to complete with error."))
            activeTasks[taskIndex].isCompleted = true
            return
        }

        continuation.resume(throwing: error)
        activeTasks[taskIndex].isCompleted = true
        loggedMessages.append(.completionFailure(task.id, task.request, error.localizedDescription))
    }

    public func complete(with data: Data, response: HTTPURLResponse, at optionalIndex: Int? = nil) {
        guard let (taskIndex, task) = findTaskState(at: optionalIndex) else {
            if optionalIndex == 0, activeTasks.isEmpty {
                let message = "[HTTPClientSpy] ERROR: Attempted to complete task at index 0 with success, but no tasks are active."
                loggedMessages.append(.spyError(message))
            }
            return
        }

        guard let continuation = continuations.removeValue(forKey: task.id) else {
            loggedMessages.append(.spyError("[HTTPClientSpy] ERROR: No continuation found for task ID \(task.id) to complete with success."))
            activeTasks[taskIndex].isCompleted = true
            return
        }

        continuation.resume(returning: (data, response))
        activeTasks[taskIndex].isCompleted = true
        loggedMessages.append(.completionSuccess(task.id, task.request))
    }

    public func complete(with data: Data, response: HTTPURLResponse, forTaskID id: UUID) {
        guard let (taskIndex, task) = findTaskState(withID: id) else { return }

        guard let continuation = continuations.removeValue(forKey: task.id) else {
            loggedMessages.append(.spyError("[HTTPClientSpy] ERROR: No continuation found for task ID \(task.id) to complete with success."))
            activeTasks[taskIndex].isCompleted = true
            return
        }

        continuation.resume(returning: (data, response))
        activeTasks[taskIndex].isCompleted = true
        loggedMessages.append(.completionSuccess(task.id, task.request))
    }

    public func getTaskID(at index: Int) -> UUID? {
        guard activeTasks.indices.contains(index) else { return nil }
        return activeTasks[index].id
    }

    public func allTasksCompleted() -> Bool {
        activeTasks.allSatisfy(\.isCompleted) && continuations.isEmpty
    }

    public func getActiveTasksCount() -> Int {
        activeTasks.filter { !$0.isCompleted }.count
    }

    public func getPendingTaskIDs() -> [UUID] {
        activeTasks.filter { !$0.isCompleted }.map(\.id)
    }

    public func reset() {
        activeTasks.removeAll()
        loggedRequests.removeAll()
        loggedMessages.removeAll()
        _sendResultsQueue.removeAll()
        continuations.removeAll()
    }
}
