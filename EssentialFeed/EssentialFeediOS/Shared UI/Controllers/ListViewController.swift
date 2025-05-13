//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import EssentialFeed
import UIKit

public final class ListViewController: UITableViewController, UITableViewDataSourcePrefetching, ResourceLoadingView, ResourceErrorView {
    public private(set) var errorView = ErrorView()

    private lazy var dataSource: UITableViewDiffableDataSource<Int, CellController> = .init(tableView: tableView) { tableView, index, controller in
        controller.dataSource.tableView(tableView, cellForRowAt: index)
    }

    public var onRefresh: (() -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        refresh()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Only clear snapshot if the view controller is being popped or dismissed.
        if isMovingFromParent || isBeingDismissed {
            // Applying an empty snapshot is a clean way to clear the diffable data source.
            if #available(iOS 13.0, *) {
                var snapshot = NSDiffableDataSourceSnapshot<Int, CellController>()
                // Ensure sections exist before trying to append/delete to avoid crashes if sections are conditional.
                // However, applying an empty snapshot is safer.
                if !dataSource.snapshot().sectionIdentifiers.isEmpty {
                    snapshot.appendSections(dataSource.snapshot().sectionIdentifiers) // Keep existing sections
                    snapshot.deleteAllItems() // Delete all items from them
                    dataSource.apply(snapshot, animatingDifferences: false)
                } else {
                    // If there are no sections (e.g. initial empty state), apply a completely empty snapshot.
                    dataSource.apply(NSDiffableDataSourceSnapshot<Int, CellController>(), animatingDifferences: false)
                }
            }
        }
    }

    deinit {
        onRefresh = nil
        errorView.onHide = nil

        // Explicitly break refreshControl cycle
        refreshControl?.removeTarget(nil, action: nil, for: .allEvents)
        refreshControl?.removeFromSuperview() // Not strictly necessary if tableView is also deallocating, but good practice.
        refreshControl = nil

        // If the tableView's refreshControl property still points to the (now nilled) refreshControl instance,
        // it's good to nil it out on the tableView as well.
        // However, self.refreshControl = nil already does this if it was the one assigned.
        // If a different refresh control instance was assigned directly to tableView.refreshControl,
        // then tableView.refreshControl = nil would be important.
        // Given self.refreshControl is the one we manage, this is likely redundant but harmless.
        if tableView.refreshControl != nil { // Check to avoid potential issues if it was already nilled by system
            tableView.refreshControl = nil
        }

        // Explicitly break tableView delegate/dataSource cycle if self is assigned to them
        // and they are not automatically nilled out by UIKit early enough.
        // For prefetchDataSource, self is the prefetchDataSource.
        if tableView.prefetchDataSource === self { // Check identity
            tableView.prefetchDataSource = nil
        }

        // The main dataSource is the UITableViewDiffableDataSource instance.
        // It should deallocate when 'self' (ListViewController) deallocates,
        // as it's a stored property.
        // If tableView held a strong reference back to it that wasn't broken,
        // then tableView.dataSource = nil would be needed.
        // However, UITableView.dataSource is typically a weak reference or managed correctly.
        // We'll add it for maximum safety, though it might be redundant.
        if tableView.dataSource === dataSource { // Check identity, though it's a lazy var of self
            tableView.dataSource = nil
        }

        // Clear the table view's header view if it's our errorView's container
        if tableView.tableHeaderView == errorView.superview { // errorView.makeContainer()
            tableView.tableHeaderView = nil
        }
    }

    private func configureTableView() {
        dataSource.defaultRowAnimation = .fade
        tableView.dataSource = dataSource
        // tableView.prefetchDataSource = self // This is set by the system if conforming to UITableViewDataSourcePrefetching
        tableView.tableHeaderView = errorView.makeContainer()

        errorView.onHide = { [weak self] in
            self?.tableView.beginUpdates()
            self?.tableView.sizeTableHeaderToFit()
            self?.tableView.endUpdates()
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        tableView.sizeTableHeaderToFit()
    }

    override public func traitCollectionDidChange(_ previous: UITraitCollection?) {
        if previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            tableView.reloadData()
        }
    }

    @IBAction private func refresh() {
        onRefresh?()
    }

    public func display(_ sections: [CellController]...) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, CellController>()
        for (section, cellControllers) in sections.enumerated() {
            snapshot.appendSections([section])
            snapshot.appendItems(cellControllers, toSection: section)
        }

        if #available(iOS 15.0, *) {
            dataSource.applySnapshotUsingReloadData(snapshot)
        } else {
            dataSource.apply(snapshot)
        }
    }

    public func display(_ viewModel: ResourceLoadingViewModel) {
        if viewModel.isLoading {
            refreshControl?.beginRefreshing()
        } else {
            refreshControl?.endRefreshing()
        }
    }

    public func display(_ viewModel: ResourceErrorViewModel) {
        errorView.message = viewModel.message
    }

    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dl = cellController(at: indexPath)?.delegate
        dl?.tableView?(tableView, didSelectRowAt: indexPath)
    }

    override public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let dl = cellController(at: indexPath)?.delegate
        dl?.tableView?(tableView, willDisplay: cell, forRowAt: indexPath)
    }

    override public func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let dl = cellController(at: indexPath)?.delegate
        dl?.tableView?(tableView, didEndDisplaying: cell, forRowAt: indexPath)
    }

    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let dsp = cellController(at: indexPath)?.dataSourcePrefetching
            dsp?.tableView(tableView, prefetchRowsAt: [indexPath])
        }
    }

    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let dsp = cellController(at: indexPath)?.dataSourcePrefetching
            dsp?.tableView?(tableView, cancelPrefetchingForRowsAt: [indexPath])
        }
    }

    private func cellController(at indexPath: IndexPath) -> CellController? {
        dataSource.itemIdentifier(for: indexPath)
    }
}
