//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import Foundation
import EssentialFeed
import EssentialFeediOS
import Combine

class LoaderSpy {
	// MARK: - FeedLoader
	private var feedRequests = [PassthroughSubject<Paginated<FeedImage>, Error>]()
	
	var loadFeedCallCount: Int = 0
	
	func loadPublisher() -> AnyPublisher<Paginated<FeedImage>, Error> {
		let publisher = PassthroughSubject<Paginated<FeedImage>, Error>()
		feedRequests.append(publisher)
		loadFeedCallCount += 1
		return publisher.eraseToAnyPublisher()
	}
	
	func completeFeedLoadingWithError(at index: Int = 0) {
		feedRequests[index].send(completion: .failure(anyNSError()))
	}
	
	func completeFeedLoading(with feed: [FeedImage] = [], isLastPage: Bool = true, at index: Int = 0) {
		feedRequests[index].send(Paginated(items: feed, loadMorePublisher: isLastPage ? nil : { [weak self] in
			self?.loadMorePublisher() ?? Empty().eraseToAnyPublisher()
		}))
		feedRequests[index].send(completion: .finished)
	}
	
	func completeFeedLoading(at index: Int = 0) {
		completeFeedLoading(with: [], isLastPage: true, at: index)
	}
	
	// MARK: - LoadMoreFeedLoader
	private var loadMoreRequests = [PassthroughSubject<Paginated<FeedImage>, Error>]()
	
	var loadMoreCallCount: Int = 0
	
	func loadMorePublisher() -> AnyPublisher<Paginated<FeedImage>, Error> {
		let publisher = PassthroughSubject<Paginated<FeedImage>, Error>()
		loadMoreRequests.append(publisher)
		loadMoreCallCount += 1
		return publisher.eraseToAnyPublisher()
	}
	
	func completeLoadMore(with feed: [FeedImage] = [], lastPage: Bool, at paginatedPublisherIndex: Int = 0) {
		guard loadMoreRequests.indices.contains(paginatedPublisherIndex) else {
			return
		}
		let paginated = Paginated(
			items: feed,
			loadMorePublisher: lastPage ? nil : { [weak self] in
				self?.loadMorePublisher() ?? Empty().eraseToAnyPublisher()
			}
		)
		loadMoreRequests[paginatedPublisherIndex].send(paginated)
		if loadMoreRequests.indices.contains(paginatedPublisherIndex) {
			loadMoreRequests[paginatedPublisherIndex].send(completion: .finished)
		}
	}
	
	func completeLoadMore(at paginatedPublisherIndex: Int = 0) {
		completeLoadMore(with: [], lastPage: true, at: paginatedPublisherIndex)
	}
	
	func completeLoadMoreWithError(at paginatedPublisherIndex: Int = 0) {
		guard loadMoreRequests.indices.contains(paginatedPublisherIndex) else { return }
		loadMoreRequests[paginatedPublisherIndex].send(completion: .failure(anyNSError()))
	}
	
	// MARK: - FeedImageDataLoader
	
	var loadedImageURLs = [URL]()
	private(set) var cancelledImageURLs = [URL]()
	private var imagePublishers = [URL: PassthroughSubject<Data, Error>]()
	
	func imageLoaderPublisher() -> (URL) -> AnyPublisher<Data, Error> {
		return { [weak self] url in
			let publisher = PassthroughSubject<Data, Error>()
			self?.imagePublishers[url] = publisher
			self?.loadedImageURLs.append(url)
			return publisher.handleEvents(receiveCancel: { [weak self] in
				self?.cancelledImageURLs.append(url)
			}).eraseToAnyPublisher()
		}
	}
	
	func completeImageLoading(with imageData: Data = Data(), for url: URL) {
		imagePublishers[url]?.send(imageData)
		imagePublishers[url]?.send(completion: .finished)
	}
	
	func completeImageLoadingWithError(for url: URL) {
		imagePublishers[url]?.send(completion: .failure(anyNSError()))
	}
	
	private func anyNSError() -> NSError {
		return NSError(domain: "any error", code: 0)
	}
}

extension FeedUIIntegrationTests {
	// Otros helpers específicos de la extensión pueden permanecer aquí si los hubiera.
}
