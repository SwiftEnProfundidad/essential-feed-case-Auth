//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import Combine
import CoreData
import EssentialFeed
import os
import SwiftUI
import UIKit

public class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    override public init() {
        self.isUserAuthenticatedClosure = {
            KeychainSessionManager(keychain: KeychainHelper()).isAuthenticated
        }
        super.init()
    }

    private var isUserAuthenticatedClosure: () -> Bool

    public var window: UIWindow?

    private lazy var scheduler: AnyDispatchQueueScheduler = DispatchQueue(
        label: "com.essentialdeveloper.infra.queue",
        qos: .userInitiated,
        attributes: .concurrent
    ).eraseToAnyScheduler()

    private lazy var httpClient: HTTPClient = URLSessionHTTPClient(session: URLSession(configuration: .ephemeral))

    private lazy var logger = Logger(
        subsystem: "com.essentialdeveloper.EssentialAppCaseStudy", category: "main"
    )

    private lazy var store: FeedStore & FeedImageDataStore = {
        do {
            return try CoreDataFeedStore(
                storeURL:
                NSPersistentContainer
                    .defaultDirectoryURL()
                    .appendingPathComponent("feed-store.sqlite"))
        } catch {
            assertionFailure(
                "Failed to instantiate CoreData store with error: \(error.localizedDescription)")
            logger.fault("Failed to instantiate CoreData store with error: \(error.localizedDescription)")
            return NullStore()
        }
    }()

    private lazy var localFeedLoader: LocalFeedLoader = .init(store: store, currentDate: Date.init)
    private lazy var baseURL = URL(string: "https://ile-api.essentialdeveloper.com/essential-feed")!

    private lazy var navigationController = UINavigationController(
        rootViewController: FeedUIComposer.feedComposedWith(
            feedLoader: makeRemoteFeedLoaderWithLocalFallback,
            imageLoader: makeLocalImageLoaderWithRemoteFallback,
            selection: showComments
        ))

    public convenience init(
        httpClient: HTTPClient, store: FeedStore & FeedImageDataStore,
        scheduler: AnyDispatchQueueScheduler,
        sessionManager: SessionManager = KeychainSessionManager(keychain: KeychainHelper())
    ) {
        self.init(sessionManager: sessionManager)
        self.httpClient = httpClient
        self.store = store
        self.scheduler = scheduler
    }

    public init(sessionManager: SessionManager = KeychainSessionManager(keychain: KeychainHelper())) {
        self.isUserAuthenticatedClosure = { sessionManager.isAuthenticated }
        super.init()
    }

    public func scene(
        _ scene: UIScene, willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        guard let scene = (scene as? UIWindowScene) else {
            return
        }
        window = UIWindow(windowScene: scene)
        configureWindow()
    }

    private func isUserAuthenticated() -> Bool {
        isUserAuthenticatedClosure()
    }

    private func makeRootViewController() -> UIViewController {
        if isUserAuthenticated() {
            navigationController
        } else {
            AuthComposer.authViewController(
                onAuthenticated: { [weak self] in
                    self?.window?.rootViewController = self?.navigationController
                },
                onRecoveryRequested: { [weak self] in
                    guard let self,
                          let window = self.window,
                          let presentingVC = window.rootViewController
                    else {
                        return
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        let recoveryScreen = PasswordRecoveryComposer.passwordRecoveryViewScreen()
                        let recoveryVC = UIHostingController(rootView: recoveryScreen)
                        presentingVC.present(recoveryVC, animated: true)
                    }
                }
            )
        }
    }

    public func configureWindow() {
        window?.rootViewController = makeRootViewController()
        window?.makeKeyAndVisible()
    }

    public func sceneWillResignActive(_: UIScene) {
        do {
            try localFeedLoader.validateCache()
        } catch {
            logger.error("Failed to validate cache with error: \(error.localizedDescription)")
        }
    }

    private func showComments(for image: FeedImage) {
        let url = ImageCommentsEndpoint.get(image.id).url(baseURL: baseURL)
        let comments = CommentsUIComposer.commentsComposedWith(
            commentsLoader: makeRemoteCommentsLoader(url: url))
        navigationController.pushViewController(comments, animated: true)
    }

    private func makeRemoteCommentsLoader(url: URL) -> () -> AnyPublisher<[ImageComment], Error> {
        { [httpClient] in
            httpClient
                .getPublisher(url: url)
                .tryMap(ImageCommentsMapper.map)
                .eraseToAnyPublisher()
        }
    }

    private func makeRemoteFeedLoaderWithLocalFallback() -> AnyPublisher<Paginated<FeedImage>, Error> {
        makeRemoteFeedLoader()
            .caching(to: localFeedLoader)
            .fallback(to: localFeedLoader.loadPublisher)
            .map(makeFirstPage)
            .subscribe(on: scheduler)
            .eraseToAnyPublisher()
    }

    private func makeRemoteLoadMoreLoader(last: FeedImage?) -> AnyPublisher<Paginated<FeedImage>, Error> {
        localFeedLoader.loadPublisher()
            .zip(makeRemoteFeedLoader(after: last))
            .map { cachedItems, newItems in
                (cachedItems + newItems, newItems.last)
            }
            .map(makePage)
            .caching(to: localFeedLoader)
            .subscribe(on: scheduler)
            .eraseToAnyPublisher()
    }

    private func makeRemoteFeedLoader(after: FeedImage? = nil) -> AnyPublisher<[FeedImage], Error> {
        let url = FeedEndpoint.get(after: after).url(baseURL: baseURL)

        return httpClient
            .getPublisher(url: url)
            .tryMap(FeedItemsMapper.map)
            .eraseToAnyPublisher()
    }

    private func makeFirstPage(items: [FeedImage]) -> Paginated<FeedImage> {
        makePage(items: items, last: items.last)
    }

    private func makePage(items: [FeedImage], last: FeedImage?) -> Paginated<FeedImage> {
        Paginated(
            items: items,
            loadMorePublisher: last.map { last in
                { self.makeRemoteLoadMoreLoader(last: last) }
            }
        )
    }

    private func makeLocalImageLoaderWithRemoteFallback(url: URL) -> FeedImageDataLoader.Publisher {
        let localImageLoader = LocalFeedImageDataLoader(store: store)

        return localImageLoader
            .loadImageDataPublisher(from: url)
            .fallback(to: { [httpClient, scheduler] in
                httpClient
                    .getPublisher(url: url)
                    .tryMap(FeedImageDataMapper.map)
                    .caching(to: localImageLoader, using: url)
                    .subscribe(on: scheduler)
                    .eraseToAnyPublisher()
            })
            .subscribe(on: scheduler)
            .eraseToAnyPublisher()
    }
}
