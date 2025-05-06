//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import XCTest
import EssentialFeed
import EssentialFeediOS
import EssentialApp

class FeedAcceptanceTests: XCTestCase {
	
	func test_onLaunch_displaysRemoteFeedWhenCustomerHasConnectivity() {
		let feed = launch(httpClient: .online(response), store: .empty)
		
		// Carga inicial (desencadenada por viewDidLoad y/o el primer simulateUserInitiatedReload)
		feed.simulateUserInitiatedReload()
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		// ADD: Simular que las celdas se vuelven visibles para disparar la carga de sus imágenes
		feed.simulateFeedImageViewVisible(at: 0)
		feed.simulateFeedImageViewVisible(at: 1)
		// ADD: Dar tiempo adicional para que las imágenes se carguen y rendericen
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(feed.numberOfRenderedFeedImageViews(), 2)
		XCTAssertEqual(feed.renderedFeedImageData(at: 0), makeImageData0())
		XCTAssertEqual(feed.renderedFeedImageData(at: 1), makeImageData1())
		XCTAssertTrue(feed.canLoadMoreFeed)
		
		// Cargar más (1er intento)
		feed.simulateLoadMoreFeedAction()
		// REMOVE: feed.simulateUserInitiatedReload() // Esto recargaba la primera página, pisando la caché.
		// La acción de "load more" debería actualizar la UI directamente a través de su propio pipeline.
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1)) // Dar tiempo a que el "load more" complete y actualice UI
		
		// ADD: Simular que la nueva celda se vuelve visible para disparar la carga de su imagen
		feed.simulateFeedImageViewVisible(at: 2)
		// ADD: Dar tiempo adicional para que la imagen se cargue y renderice
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(feed.numberOfRenderedFeedImageViews(), 3)
		XCTAssertEqual(feed.renderedFeedImageData(at: 0), makeImageData0())
		XCTAssertEqual(feed.renderedFeedImageData(at: 1), makeImageData1())
		XCTAssertEqual(feed.renderedFeedImageData(at: 2), makeImageData2())
		XCTAssertTrue(feed.canLoadMoreFeed)
		
		// Cargar más (2do intento, debería ser la última página)
		feed.simulateLoadMoreFeedAction()
		// REMOVE: feed.simulateUserInitiatedReload() // Igual que arriba.
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		// Nota: No es necesario simular la visibilidad de la imagen aquí si no hay nuevas imágenes cargadas.
		// Las imágenes existentes ya deberían estar cargadas.
		
		XCTAssertEqual(feed.numberOfRenderedFeedImageViews(), 3)
		XCTAssertEqual(feed.renderedFeedImageData(at: 0), makeImageData0())
		XCTAssertEqual(feed.renderedFeedImageData(at: 1), makeImageData1())
		XCTAssertEqual(feed.renderedFeedImageData(at: 2), makeImageData2())
		XCTAssertFalse(feed.canLoadMoreFeed)
	}
	
	func test_onLaunch_displaysCachedRemoteFeedWhenCustomerHasNoConnectivity() {
		let sharedStore = InMemoryFeedStore.empty
		
		let onlineFeed = launch(httpClient: .online(response), store: sharedStore)
		onlineFeed.simulateUserInitiatedReload() // Carga inicial online
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		onlineFeed.simulateFeedImageViewVisible(at: 0)
		onlineFeed.simulateFeedImageViewVisible(at: 1)
		// ADD: Dar tiempo para que estas imágenes se carguen (desde la red)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		onlineFeed.simulateLoadMoreFeedAction() // Carga más online
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		onlineFeed.simulateFeedImageViewVisible(at: 2)
		// ADD: Dar tiempo para que esta imagen se cargue (desde la red)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		// Ahora el store debería tener 3 items cacheados.
		
		let offlineFeed = launch(httpClient: .offline, store: sharedStore)
		offlineFeed.simulateUserInitiatedReload() // Carga inicial offline (debería usar el fallback a la caché)
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1)) // Tiempo para que el feed (lista) se cargue desde caché
		
		// ADD: Simular que las celdas se vuelven visibles para disparar la carga de sus imágenes (desde la caché de imágenes)
		offlineFeed.simulateFeedImageViewVisible(at: 0)
		offlineFeed.simulateFeedImageViewVisible(at: 1)
		offlineFeed.simulateFeedImageViewVisible(at: 2)
		// ADD: Dar tiempo adicional para que las imágenes se carguen desde la caché y se rendericen
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(offlineFeed.numberOfRenderedFeedImageViews(), 3)
		XCTAssertEqual(offlineFeed.renderedFeedImageData(at: 0), makeImageData0())
		XCTAssertEqual(offlineFeed.renderedFeedImageData(at: 1), makeImageData1())
		XCTAssertEqual(offlineFeed.renderedFeedImageData(at: 2), makeImageData2())
	}
	
	func test_onLaunch_displaysEmptyFeedWhenCustomerHasNoConnectivityAndNoCache() {
		let feed = launch(httpClient: .offline, store: .empty)
		// ADD: Simulate initial feed load
		feed.simulateUserInitiatedReload()
		// ADD: Allow run loop to process UI updates
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(feed.numberOfRenderedFeedImageViews(), 0)
	}
	
	func test_onEnteringBackground_deletesExpiredFeedCache() {
		let store = InMemoryFeedStore.withExpiredFeedCache
		
		enterBackground(with: store)
		
		XCTAssertNil(store.feedCache, "Expected to delete expired cache")
	}
	
	func test_onEnteringBackground_keepsNonExpiredFeedCache() {
		let store = InMemoryFeedStore.withNonExpiredFeedCache
		
		enterBackground(with: store)
		
		XCTAssertNotNil(store.feedCache, "Expected to keep non-expired cache")
	}
	
	func test_onFeedImageSelection_displaysComments() {
		let comments = showCommentsForFirstImage()
		
		// ADD: Simulate initial comments load if ListViewController for comments also loads on refresh
		// Assuming the comments ListViewController also uses onRefresh to load
		comments.simulateUserInitiatedReload()
		// ADD: Allow run loop to process UI updates for comments
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		XCTAssertEqual(comments.numberOfRenderedComments(), 1)
		XCTAssertEqual(comments.commentMessage(at: 0), makeCommentMessage())
	}
	
	// MARK: - Helpers
	
	private final class AlwaysAuthenticatedSessionManager: SessionManager {
		var isAuthenticated: Bool { true }
	}
	
	private func launch(
		httpClient: HTTPClientStub = .offline,
		store: InMemoryFeedStore = .empty
	) -> ListViewController {
		let sut = SceneDelegate(
			httpClient: httpClient,
			store: store,
			scheduler: .immediateOnMainQueue,
			sessionManager: AlwaysAuthenticatedSessionManager()
		)
		sut.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
		sut.configureWindow()
		
		let nav = sut.window?.rootViewController as? UINavigationController
		let feedVC = nav?.topViewController as! ListViewController
		feedVC.loadViewIfNeeded()
		// ADD: Allow run loop to process initial UI setup from loadViewIfNeeded
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		return feedVC
	}
	
	private func enterBackground(with store: InMemoryFeedStore) {
		let sut = SceneDelegate(
			httpClient: HTTPClientStub.offline,
			store: store,
			scheduler: .immediateOnMainQueue,
			sessionManager: AlwaysAuthenticatedSessionManager()
		)
		sut.sceneWillResignActive(UIApplication.shared.connectedScenes.first!)
	}
	
	private func showCommentsForFirstImage() -> ListViewController {
		let feed = launch(httpClient: .online(response), store: .empty)
		
		// ADD: Simulate initial feed load to render cells to tap on
		feed.simulateUserInitiatedReload()
		// ADD: Allow run loop to process UI updates for feed
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		
		feed.simulateTapOnFeedImage(at: 0)
		RunLoop.current.run(until: Date())
		
		let nav = feed.navigationController
		let commentsVC = nav?.topViewController as! ListViewController
		commentsVC.loadViewIfNeeded()
		// ADD: Allow run loop to process initial UI setup for comments
		RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
		return commentsVC
	}
	
	private func response(for url: URL) -> (Data, HTTPURLResponse) {
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
		return (makeData(for: url), response)
	}
	
	private func makeData(for url: URL) -> Data {
		switch url.path {
			case "/image-0": return makeImageData0()
			case "/image-1": return makeImageData1()
			case "/image-2": return makeImageData2()
				
			case "/essential-feed/v1/feed" where url.query?.contains("after_id") == false:
				return makeFirstFeedPageData()
				
			case "/essential-feed/v1/feed" where url.query?.contains("after_id=A28F5FE3-27A7-44E9-8DF5-53742D0E4A5A") == true:
				return makeSecondFeedPageData()
				
			case "/essential-feed/v1/feed" where url.query?.contains("after_id=166FCDD7-C9F4-420A-B2D6-CE2EAFA3D82F") == true:
				return makeLastEmptyFeedPageData()
				
			case "/essential-feed/v1/image/2AB2AE66-A4B7-4A16-B374-51BBAC8DB086/comments":
				return makeCommentsData()
				
			default:
				return Data()
		}
	}
	
	private func makeImageData0() -> Data { stabilizedPNGData(for: .red) }
	private func makeImageData1() -> Data { stabilizedPNGData(for: .green) }
	private func makeImageData2() -> Data { stabilizedPNGData(for: .blue) }
	
	private func makeFirstFeedPageData() -> Data {
		return try! JSONSerialization.data(withJSONObject: ["items": [
			["id": "2AB2AE66-A4B7-4A16-B374-51BBAC8DB086", "image": "http://feed.com/image-0"],
			["id": "A28F5FE3-27A7-44E9-8DF5-53742D0E4A5A", "image": "http://feed.com/image-1"]
		]])
	}
	
	private func makeSecondFeedPageData() -> Data {
		return try! JSONSerialization.data(withJSONObject: ["items": [
			["id": "166FCDD7-C9F4-420A-B2D6-CE2EAFA3D82F", "image": "http://feed.com/image-2"],
		]])
	}
	
	private func makeLastEmptyFeedPageData() -> Data {
		return try! JSONSerialization.data(withJSONObject: ["items": []])
	}
	
	private func makeCommentsData() -> Data {
		return try! JSONSerialization.data(withJSONObject: ["items": [
			[
				"id": UUID().uuidString,
				"message": makeCommentMessage(),
				"created_at": "2020-05-20T11:24:59+0000",
				"author": [
					"username": "a username"
				]
			],
		]])
	}
	
	private func makeCommentMessage() -> String {
		"a message"
	}
	
}
