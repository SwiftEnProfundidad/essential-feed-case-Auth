//
// Copyright 2020 Essential Developer. All rights reserved.
//

import Combine
import EssentialApp
import EssentialFeed
import EssentialFeediOS
import UIKit
import XCTest

class CommentsUIIntegrationTests: XCTestCase {
    func test_commentsView_hasTitle() {
        autoreleasepool {
            let (sut, _) = makeSUT()
            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()
            XCTAssertEqual(sut.title, commentsTitle)
        }
    }

    func test_loadCommentsActions_requestCommentsFromLoader() {
        var sut: ListViewController?
        var loader: LoaderSpy?

        autoreleasepool {
            let (createdSUT, createdLoader) = makeSUT()
            sut = createdSUT
            loader = createdLoader

            XCTAssertEqual(loader!.loadCommentsCallCount, 0, "Expected 0 loading request before view is loaded")

            sut!.loadViewIfNeeded()
            sut!.replaceRefreshControlWithFakeForiOS17Support()
            XCTAssertEqual(loader!.loadCommentsCallCount, 1, "Expected 1 loading request after view is loaded")

            sut!.simulateUserInitiatedReload()
            XCTAssertEqual(loader!.loadCommentsCallCount, 1, "Expected no new request until previous completes")

            loader!.completeCommentsLoading(at: 0)
            sut!.simulateUserInitiatedReload()
            XCTAssertEqual(loader!.loadCommentsCallCount, 2, "Expected another loading request once user initiates a reload")

            loader!.completeCommentsLoading(at: 1)
            sut!.simulateUserInitiatedReload()
            XCTAssertEqual(loader!.loadCommentsCallCount, 3, "Expected yet another loading request once user initiates another reload")
        }
    }

    func test_loadingCommentsIndicator_isVisibleWhileLoadingComments() {
        let (sut, loader) = makeSUT()

        sut.loadViewIfNeeded()
        sut.replaceRefreshControlWithFakeForiOS17Support()

        if let fakeRefreshControl = sut.refreshControl as? FakeRefreshControl {
            fakeRefreshControl.beginRefreshing()
        }

        XCTAssertTrue(sut.isShowingLoadingIndicator, "Expected loading indicator after view is loaded, refresh is called, and fake refresh control is explicitly started.")

        loader.completeCommentsLoading(at: 0)
        XCTAssertFalse(sut.isShowingLoadingIndicator, "Expected no loading indicator once loading completes successfully")

        sut.simulateUserInitiatedReload()
        XCTAssertTrue(sut.isShowingLoadingIndicator, "Expected loading indicator once user initiates a reload")

        loader.completeCommentsLoadingWithError(at: 1)
        XCTAssertFalse(sut.isShowingLoadingIndicator, "Expected no loading indicator once user initiated loading completes with error")
    }

    func test_loadCommentsCompletion_rendersSuccessfullyLoadedComments() {
        autoreleasepool {
            let comment0 = makeComment(message: "a message", username: "a username")
            let comment1 = makeComment(message: "another message", username: "another username")
            let (sut, loader) = makeSUT()

            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()
            assertThat(sut, isRendering: [])

            loader.completeCommentsLoading(with: [comment0], at: 0)
            assertThat(sut, isRendering: [comment0])

            sut.simulateUserInitiatedReload()
            loader.completeCommentsLoading(with: [comment0, comment1], at: 1)
            assertThat(sut, isRendering: [comment0, comment1])
        }
    }

    func test_loadCommentsCompletion_rendersSuccessfullyLoadedEmptyCommentsAfterNonEmptyComments() {
        autoreleasepool {
            let comment = makeComment()
            let (sut, loader) = makeSUT()

            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()
            loader.completeCommentsLoading(with: [comment], at: 0)
            assertThat(sut, isRendering: [comment])

            sut.simulateUserInitiatedReload()
            loader.completeCommentsLoading(with: [], at: 1)
            assertThat(sut, isRendering: [])
        }
    }

    func test_loadCommentsCompletion_doesNotAlterCurrentRenderingStateOnError() {
        autoreleasepool {
            let comment = makeComment()
            let (sut, loader) = makeSUT()

            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()
            loader.completeCommentsLoading(with: [comment], at: 0)
            assertThat(sut, isRendering: [comment])

            sut.simulateUserInitiatedReload()
            loader.completeCommentsLoadingWithError(at: 1)
            assertThat(sut, isRendering: [comment])
        }
    }

    func test_loadCommentsCompletion_dispatchesFromBackgroundToMainThread() {
        autoreleasepool {
            let (sut, loader) = makeSUT()
            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()

            let exp = expectation(description: "Wait for background queue")
            DispatchQueue.global().async {
                loader.completeCommentsLoading(at: 0)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 1.0)
        }
    }

    func test_loadCommentsCompletion_rendersErrorMessageOnErrorUntilNextReload() {
        autoreleasepool {
            let (sut, loader) = makeSUT()

            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()
            XCTAssertEqual(sut.errorMessage, nil)

            loader.completeCommentsLoadingWithError(at: 0)
            XCTAssertEqual(sut.errorMessage, loadError)

            sut.simulateUserInitiatedReload()
            XCTAssertEqual(sut.errorMessage, nil)
        }
    }

    func test_tapOnErrorView_hidesErrorMessage() {
        autoreleasepool {
            let (sut, loader) = makeSUT()

            sut.loadViewIfNeeded()
            sut.replaceRefreshControlWithFakeForiOS17Support()
            XCTAssertEqual(sut.errorMessage, nil)

            loader.completeCommentsLoadingWithError(at: 0)
            XCTAssertEqual(sut.errorMessage, loadError)

            sut.simulateErrorViewTap()
            XCTAssertEqual(sut.errorMessage, nil)
        }
    }

    func test_deinit_cancelsRunningRequest() {
        var cancelCallCount = 0
        var sut: ListViewController?

        autoreleasepool {
            sut = CommentsUIComposer.commentsComposedWith(commentsLoader: {
                PassthroughSubject<[ImageComment], Error>()
                    .handleEvents(receiveCancel: {
                        cancelCallCount += 1
                    }).eraseToAnyPublisher()
            })

            sut?.loadViewIfNeeded()
        }
        sut = nil

        XCTAssertEqual(cancelCallCount, 1, "Expected cancel event on deinit")
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: ListViewController, loader: LoaderSpy) {
        let loader = LoaderSpy()
        let sut = CommentsUIComposer.commentsComposedWith(commentsLoader: loader.loadPublisher)
        trackForMemoryLeaks(loader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, loader)
    }

    private func makeComment(message: String = "any message", username: String = "any username") -> ImageComment {
        ImageComment(id: UUID(), message: message, createdAt: Date(), username: username)
    }

    private func assertThat(_ sut: ListViewController, isRendering comments: [ImageComment], file: StaticString = #filePath, line: UInt = #line) {
        sut.view.layoutIfNeeded()

        guard sut.numberOfRenderedComments() == comments.count else {
            XCTFail("Expected \(comments.count) comments, got \(sut.numberOfRenderedComments()) instead.", file: file, line: line)
            return
        }

        let viewModel = ImageCommentsPresenter.map(comments)

        for (index, comment) in viewModel.comments.enumerated() {
            XCTAssertEqual(sut.commentMessage(at: index), comment.message, "message at \(index)", file: file, line: line)
            XCTAssertEqual(sut.commentDate(at: index), comment.date, "date at \(index)", file: file, line: line)
            XCTAssertEqual(sut.commentUsername(at: index), comment.username, "username at \(index)", file: file, line: line)
        }
    }

    private class LoaderSpy {
        private var requests = [PassthroughSubject<[ImageComment], Error>]()

        var loadCommentsCallCount: Int {
            requests.count
        }

        func loadPublisher() -> AnyPublisher<[ImageComment], Error> {
            let publisher = PassthroughSubject<[ImageComment], Error>()
            requests.append(publisher)
            return publisher.eraseToAnyPublisher()
        }

        func completeCommentsLoading(with comments: [ImageComment] = [], at index: Int = 0) {
            guard requests.indices.contains(index) else {
                return
            }
            requests[index].send(comments)
            requests[index].send(completion: .finished)
        }

        func completeCommentsLoadingWithError(at index: Int = 0) {
            guard requests.indices.contains(index) else {
                return
            }
            let error = NSError(domain: "an error", code: 0)
            requests[index].send(completion: .failure(error))
        }
    }
}
