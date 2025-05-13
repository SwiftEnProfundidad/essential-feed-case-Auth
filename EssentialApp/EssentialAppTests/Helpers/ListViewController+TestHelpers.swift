//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import EssentialFeediOS
import UIKit

extension ListViewController {
    func simulateUserInitiatedReload() {
        refreshControl?.simulatePullToRefresh()
    }

    var isShowingLoadingIndicator: Bool {
        refreshControl?.isRefreshing == true
    }

    func simulateErrorViewTap() {
        errorView.simulateTap()
    }

    var errorMessage: String? {
        errorView.message
    }

    func numberOfRows(in section: Int) -> Int {
        tableView.numberOfSections > section ? tableView.numberOfRows(inSection: section) : 0
    }

    func cell(row: Int, section: Int) -> UITableViewCell? {
        guard numberOfRows(in: section) > row else {
            return nil
        }
        let ds = tableView.dataSource
        let index = IndexPath(row: row, section: section)
        return ds?.tableView(tableView, cellForRowAt: index)
    }

    func simulateAppearance() {
        if !isViewLoaded {
            loadViewIfNeeded()
        }
        // Dejamos la simulación de viewWillAppear/Appear comentada por ahora,
        // ya que la estrategia principal es loadViewIfNeeded y el FakeRefreshControl.
        // viewWillAppear(false)
        // viewDidAppear(false)
    }

    public func replaceRefreshControlWithFakeForiOS17Support() {
        let fake = FakeRefreshControl()

        if let originalRefreshControl = self.refreshControl {
            for target in originalRefreshControl.allTargets {
                originalRefreshControl.actions(forTarget: target, forControlEvent: UIControl.Event.valueChanged)?.forEach { action in
                    fake.addTarget(target, action: Selector(action), for: UIControl.Event.valueChanged)
                }
            }

            // --- INICIO DEL CAMBIO ---
            // Se elimina la condición: if originalRefreshControl.isRefreshing {
            // Ahora llamamos a fake.beginRefreshing() directamente.
            //
            // Justificación:
            // La carga inicial siempre se dispara en viewDidLoad -> refresh().
            // Esta función de reemplazo se llama DESPUÉS de que esa carga inicial ha comenzado.
            // Por lo tanto, asumimos que el FakeRefreshControl debe comenzar en estado "refrescando".
            // El Presenter se encargará de llamar a endRefreshing() cuando la carga inicial
            // (o cualquier carga posterior) se complete.
            // Esto evita depender del estado de `originalRefreshControl.isRefreshing`,
            // que puede no ser fiable si `beginRefreshing()` se llamó mientras el control
            // estaba fuera de pantalla (lo que causa la advertencia de iOS).
            fake.beginRefreshing()
            // --- FIN DEL CAMBIO ---
        }

        self.refreshControl = fake
    }
}

extension ListViewController {
    func numberOfRenderedComments() -> Int {
        numberOfRows(in: commentsSection)
    }

    func commentMessage(at row: Int) -> String? {
        commentView(at: row)?.messageLabel.text
    }

    func commentDate(at row: Int) -> String? {
        commentView(at: row)?.dateLabel.text
    }

    func commentUsername(at row: Int) -> String? {
        commentView(at: row)?.usernameLabel.text
    }

    private func commentView(at row: Int) -> ImageCommentCell? {
        cell(row: row, section: commentsSection) as? ImageCommentCell
    }

    private var commentsSection: Int { 0 }
}

extension ListViewController {
    @discardableResult
    func simulateFeedImageViewVisible(at index: Int) -> FeedImageCell? {
        feedImageView(at: index) as? FeedImageCell
    }

    @discardableResult
    func simulateFeedImageViewNotVisible(at row: Int) -> FeedImageCell? {
        let view = simulateFeedImageViewVisible(at: row)

        let delegate = tableView.delegate
        let index = IndexPath(row: row, section: feedImagesSection)
        delegate?.tableView?(tableView, didEndDisplaying: view!, forRowAt: index)

        return view
    }

    func simulateTapOnFeedImage(at row: Int) {
        let delegate = tableView.delegate
        let index = IndexPath(row: row, section: feedImagesSection)
        delegate?.tableView?(tableView, didSelectRowAt: index)
    }

    func simulateFeedImageViewNearVisible(at row: Int) {
        let ds = tableView.prefetchDataSource
        let index = IndexPath(row: row, section: feedImagesSection)
        ds?.tableView(tableView, prefetchRowsAt: [index])
    }

    func simulateFeedImageViewNotNearVisible(at row: Int) {
        simulateFeedImageViewNearVisible(at: row)

        let ds = tableView.prefetchDataSource
        let index = IndexPath(row: row, section: feedImagesSection)
        ds?.tableView?(tableView, cancelPrefetchingForRowsAt: [index])
    }

    func simulateLoadMoreFeedAction() {
        guard let view = loadMoreFeedCell() else { return }

        let delegate = tableView.delegate
        let index = IndexPath(row: 0, section: feedLoadMoreSection)
        delegate?.tableView?(tableView, willDisplay: view, forRowAt: index)
    }

    func simulateTapOnLoadMoreFeedError() {
        let delegate = tableView.delegate
        let index = IndexPath(row: 0, section: feedLoadMoreSection)
        delegate?.tableView?(tableView, didSelectRowAt: index)
    }

    var isShowingLoadMoreFeedIndicator: Bool {
        loadMoreFeedCell()?.isLoading == true
    }

    var loadMoreFeedErrorMessage: String? {
        loadMoreFeedCell()?.message
    }

    var canLoadMoreFeed: Bool {
        loadMoreFeedCell() != nil
    }

    private func loadMoreFeedCell() -> LoadMoreCell? {
        cell(row: 0, section: feedLoadMoreSection) as? LoadMoreCell
    }

    func renderedFeedImageData(at index: Int) -> Data? {
        simulateFeedImageViewVisible(at: index)?.renderedImage
    }

    func numberOfRenderedFeedImageViews() -> Int {
        numberOfRows(in: feedImagesSection)
    }

    func feedImageView(at row: Int) -> UITableViewCell? {
        cell(row: row, section: feedImagesSection)
    }

    private var feedImagesSection: Int { 0 }
    private var feedLoadMoreSection: Int { 1 }
}
