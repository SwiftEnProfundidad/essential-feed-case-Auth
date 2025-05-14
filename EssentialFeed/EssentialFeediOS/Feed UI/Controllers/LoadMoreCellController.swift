//
// Copyright © 2020 Essential Developer. All rights reserved.
//

import EssentialFeed
import UIKit

public class LoadMoreCellController: NSObject, UITableViewDataSource, UITableViewDelegate {
    private let cell = LoadMoreCell()
    private let callback: () -> Void
    private var offsetObserver: NSKeyValueObservation?

    public init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    public func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        1
    }

    public func tableView(_: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        cell.selectionStyle = .none
        return cell
    }

    public func tableView(_ tableView: UITableView, willDisplay _: UITableViewCell, forRowAt _: IndexPath) {
        reloadIfNeeded()

        offsetObserver = tableView.observe(\.contentOffset, options: .new) { [weak self] tableView, _ in
            guard tableView.isDragging else { return }

            self?.reloadIfNeeded()
        }
    }

    public func tableView(_: UITableView, didEndDisplaying _: UITableViewCell, forRowAt _: IndexPath) {
        offsetObserver = nil
    }

    public func tableView(_: UITableView, didSelectRowAt _: IndexPath) {
        reloadIfNeeded()
    }

    private func reloadIfNeeded() {
        guard !cell.isLoading else { return }

        callback()
    }
}

extension LoadMoreCellController: ResourceLoadingView, ResourceErrorView {
    public func display(_ viewModel: ResourceErrorViewModel) {
        cell.message = viewModel.message
    }

    public func display(_ viewModel: ResourceLoadingViewModel) {
        cell.isLoading = viewModel.isLoading
    }
}
