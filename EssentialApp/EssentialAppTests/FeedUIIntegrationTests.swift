//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import XCTest
import UIKit
import EssentialApp
import EssentialFeed
import EssentialFeediOS

class FeedUIIntegrationTests: XCTestCase {
	
	private var window: UIWindow?
	
	override func tearDown() {
		window?.rootViewController = nil
		window = nil
		super.tearDown()
	}
	
	func test_feedView_hasTitle() {
		let (sut, _) = makeSUT()
		XCTAssertEqual(sut.title, feedTitle)
	}
	
	func test_imageSelection_notifiesHandler() {
		let image0 = makeImage()
		let image1 = makeImage()
		var selectedImages = [FeedImage]()
		let (sut, loader) = makeSUT(selection: { selectedImages.append($0) })
		
		loader.completeFeedLoading(with: [image0, image1], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		sut.simulateTapOnFeedImage(at: 0)
		XCTAssertEqual(selectedImages, [image0])
		
		sut.simulateTapOnFeedImage(at: 1)
		XCTAssertEqual(selectedImages, [image0, image1])
	}
	
	func test_loadFeedActions_requestFeedFromLoader() {
		let (sut, loader) = makeSUT()
		
		XCTAssertEqual(loader.loadFeedCallCount, 1, "Expected 1 loading request after view is loaded and appears")
		
		sut.simulateUserInitiatedReload()
		XCTAssertEqual(loader.loadFeedCallCount, 1, "Expected no new request until previous completes")
		
		loader.completeFeedLoading(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
		
		sut.simulateUserInitiatedReload()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
		XCTAssertEqual(loader.loadFeedCallCount, 2, "Expected another loading request once user initiates a reload")
		
		loader.completeFeedLoading(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
		
		sut.simulateUserInitiatedReload()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
		XCTAssertEqual(loader.loadFeedCallCount, 3, "Expected yet another loading request once user initiates another reload")
	}
	
	func test_loadingFeedIndicator_isVisibleWhileLoadingFeed() {
		let (sut, loader) = makeSUT()
		
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertTrue(sut.isShowingLoadingIndicator, "Expected loading indicator once view appears")
		
		loader.completeFeedLoading(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertFalse(sut.isShowingLoadingIndicator, "Expected no loading indicator once loading completes successfully")
		
		sut.simulateUserInitiatedReload()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertTrue(sut.isShowingLoadingIndicator, "Expected loading indicator once user initiates a reload")
		
		loader.completeFeedLoadingWithError(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertFalse(sut.isShowingLoadingIndicator, "Expected no loading indicator once user initiated loading completes with error")
	}
	
	func test_loadFeedCompletion_rendersSuccessfullyLoadedFeed() {
		let image0 = makeImage(description: "a description", location: "a location")
		let image1 = makeImage(description: nil, location: "another location")
		let image2 = makeImage(description: "another description", location: nil)
		let image3 = makeImage(description: nil, location: nil)
		let (sut, loader) = makeSUT()
		
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		assertThat(sut, isRendering: [])
		
		loader.completeFeedLoading(with: [image0, image1], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		assertThat(sut, isRendering: [image0, image1])
		
		sut.simulateLoadMoreFeedAction()
		loader.completeLoadMore(with: [image0, image1, image2, image3], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		assertThat(sut, isRendering: [image0, image1, image2, image3])
		
		sut.simulateUserInitiatedReload()
		loader.completeFeedLoading(with: [image0, image1, image2, image3], at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		assertThat(sut, isRendering: [image0, image1, image2, image3])
	}
	
	// MARK: - Load More Tests
	
	func test_loadMoreActions_requestMoreFromLoader() {
		let (sut, loader) = makeSUT()
		
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		loader.completeFeedLoading(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(loader.loadMoreCallCount, 0, "Expected no load more requests before action")
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadMoreCallCount, 1, "Expected load more request after action")
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadMoreCallCount, 1, "Expected no request while loading more")
		
		loader.completeLoadMore(lastPage: false, at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadMoreCallCount, 2, "Expected request after load more completed with more pages")
		
		loader.completeLoadMoreWithError(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadMoreCallCount, 3, "Expected request after load more failure")
		
		loader.completeLoadMore(lastPage: true, at: 2)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadMoreCallCount, 3, "Expected no request after loading all pages")
	}
	
	func test_loadingMoreIndicator_isVisibleWhileLoadingMore() {
		let (sut, loader) = makeSUT()
		
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertFalse(sut.isShowingLoadMoreFeedIndicator, "Expected no loading indicator once view appears")
		
		loader.completeFeedLoading(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertFalse(sut.isShowingLoadMoreFeedIndicator, "Expected no loading indicator after initial load completes")
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertTrue(sut.isShowingLoadMoreFeedIndicator, "Expected loading indicator on load more action")
		
		loader.completeLoadMore(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertFalse(sut.isShowingLoadMoreFeedIndicator, "Expected no loading indicator after load more completes successfully")
		
		sut.simulateLoadMoreFeedAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertTrue(sut.isShowingLoadMoreFeedIndicator, "Expected loading indicator on second load more action")
		
		loader.completeLoadMoreWithError(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertFalse(sut.isShowingLoadMoreFeedIndicator, "Expected no loading indicator after load more completes with error")
	}
	
	// ... Para los tests de imágenes individuales (feedImageView...)
	// Asegurarse de que la carga inicial del feed se complete Y la UI se actualice antes de simular visibilidad de celdas.
	
	func test_feedImageView_loadsImageURLWhenVisible() {
		let image0 = makeImage(url: URL(string: "http://url-0.com")!)
		let image1 = makeImage(url: URL(string: "http://url-1.com")!)
		let (sut, loader) = makeSUT()
		
		loader.completeFeedLoading(with: [image0, image1], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(loader.loadedImageURLs, [], "Expected no image URL requests until views become visible")
		
		sut.simulateFeedImageViewVisible(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadedImageURLs, [image0.url], "Expected first image URL request once first view becomes visible")
		
		sut.simulateFeedImageViewVisible(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadedImageURLs, [image0.url, image1.url], "Expected second image URL request once second view becomes visible")
	}
	
	func test_feedImageViewLoadingIndicator_isVisibleWhileLoadingImage() {
		let (sut, loader) = makeSUT()
		
		loader.completeFeedLoading(with: [makeImage(), makeImage()], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		let view0 = sut.simulateFeedImageViewVisible(at: 0)
		let view1 = sut.simulateFeedImageViewVisible(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(view0?.isShowingImageLoadingIndicator, true, "Expected loading indicator for first view while loading first image")
		XCTAssertEqual(view1?.isShowingImageLoadingIndicator, true, "Expected loading indicator for second view while loading second image")
		
		loader.completeImageLoading(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view0?.isShowingImageLoadingIndicator, false, "Expected no loading indicator for first view once first image loading completes successfully")
		XCTAssertEqual(view1?.isShowingImageLoadingIndicator, true, "Expected no loading indicator state change for second view once first image loading completes successfully")
		
		loader.completeImageLoadingWithError(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view0?.isShowingImageLoadingIndicator, false, "Expected no loading indicator state change for first view once second image loading completes with error")
		XCTAssertEqual(view1?.isShowingImageLoadingIndicator, false, "Expected no loading indicator for second view once second image loading completes with error")
		
		view1?.simulateRetryAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view0?.isShowingImageLoadingIndicator, false, "Expected no loading indicator state change for first view on  second image retry")
		XCTAssertEqual(view1?.isShowingImageLoadingIndicator, true, "Expected loading indicator state change for second view on retry")
	}
	
	func test_feedImageViewRetryButton_isVisibleOnImageURLLoadError() {
		let (sut, loader) = makeSUT()
		
		loader.completeFeedLoading(with: [makeImage(), makeImage()], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		let view0 = sut.simulateFeedImageViewVisible(at: 0)
		let view1 = sut.simulateFeedImageViewVisible(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action for first view while loading first image")
		XCTAssertEqual(view1?.isShowingRetryAction, false, "Expected no retry action for second view while loading second image")
		
		let imageData = stabilizedPNGData(for: .red)
		loader.completeImageLoading(with: imageData, at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action for first view once first image loading completes successfully")
		XCTAssertEqual(view1?.isShowingRetryAction, false, "Expected no retry action state change for second view once first image loading completes successfully")
		
		loader.completeImageLoadingWithError(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action state change for first view once second image loading completes with error")
		XCTAssertEqual(view1?.isShowingRetryAction, true, "Expected retry action for second view once second image loading completes with error")
		
		view1?.simulateRetryAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action state change for first view on  second image retry")
		XCTAssertEqual(view1?.isShowingRetryAction, false, "Expected no retry action for second view on retry")
	}
	
	func test_feedImageViewRetryButton_isVisibleOnInvalidImageData() {
		let (sut, loader) = makeSUT()
		
		loader.completeFeedLoading(with: [makeImage()], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		let view = sut.simulateFeedImageViewVisible(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view?.isShowingRetryAction, false, "Expected no retry action while loading image")
		
		let invalidImageData = Data("invalid image data".utf8)
		loader.completeImageLoading(with: invalidImageData, at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view?.isShowingRetryAction, true, "Expected retry action on invalid image data error")
		
		view?.simulateRetryAction()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(view?.isShowingRetryAction, false, "Expected no retry action on retry")
	}
	
	func test_feedImageView_preloadsImageURLWhenNearVisible() {
		let image0 = makeImage(url: URL(string: "http://url-0.com")!)
		let image1 = makeImage(url: URL(string: "http://url-1.com")!)
		let (sut, loader) = makeSUT()
		
		loader.completeFeedLoading(with: [image0, image1], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(loader.loadedImageURLs, [], "Expected no image URL requests until image is near visible")
		
		sut.simulateFeedImageViewNearVisible(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadedImageURLs, [image0.url], "Expected first image URL request once first image is near visible")
		
		sut.simulateFeedImageViewNearVisible(at: 1)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		XCTAssertEqual(loader.loadedImageURLs, [image0.url, image1.url], "Expected second image URL request once second image is near visible")
	}
	
	func test_feedImageView_doesNotLoadImageAgainUntilPreviousRequestCompletes() {
		let image = makeImage(url: URL(string: "http://url-0.com")!)
		let (sut, loader) = makeSUT()
		
		loader.completeFeedLoading(with: [image, makeImage()], at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		sut.simulateFeedImageViewNearVisible(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
		sut.simulateFeedImageViewVisible(at: 0)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
		
		XCTAssertEqual(loader.loadedImageURLs, [image.url, image.url], "Expected two image URL requests once first image is near visible and then visible")
	}
	
	// MARK: - Helpers
	
	private func makeSUT(
		selection: @escaping (FeedImage) -> Void = { _ in },
		file: StaticString = #filePath,
		line: UInt = #line
	) -> (sut: ListViewController, loader: LoaderSpy) {
		let loader = LoaderSpy()
		let sut = FeedUIComposer.feedComposedWith(
			feedLoader: loader.loadPublisher,
			imageLoader: loader.loadImageDataPublisher,
			selection: selection
		)
		
		let currentWindow = UIWindow(frame: UIScreen.main.bounds)
		currentWindow.rootViewController = sut
		currentWindow.makeKeyAndVisible()
		
		self.window = currentWindow
		
		return (sut, loader)
	}
	
	private func makeImage(description: String? = nil, location: String? = nil, url: URL = URL(string: "http://any-url.com")!) -> FeedImage {
		return FeedImage(id: UUID(), description: description, location: location, url: url)
	}
	
	private func anyImageData() -> Data {
		return UIImage.make(withColor: .red).pngData()!
	}
	
	private func stabilizedPNGData(for color: UIColor) -> Data {
		let image = UIImage.make(withColor: color)
		let data = image.pngData()!
		return data
	}
}
