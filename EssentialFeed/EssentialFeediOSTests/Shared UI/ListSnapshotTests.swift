//
// Copyright 2020 Essential Developer. All rights reserved.
//

import EssentialFeed
import EssentialFeediOS
import XCTest

class ListSnapshotTests: XCTestCase {
    func test_emptyList() {
        let sut = makeSUT()

        sut.display(emptyList())

        if isRecording {
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light)), named: "EMPTY_LIST_light")
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .dark)), named: "EMPTY_LIST_dark")
        } else {
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light)), named: "EMPTY_LIST_light")
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .dark)), named: "EMPTY_LIST_dark")
        }
    }

    func test_listWithErrorMessage() {
        let sut = makeSUT()

        sut.display(.error(message: "This is a\nmulti-line\nerror message"))

        if isRecording {
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light)), named: "LIST_WITH_ERROR_MESSAGE_light")
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .dark)), named: "LIST_WITH_ERROR_MESSAGE_dark")
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light, contentSize: .extraExtraExtraLarge)), named: "LIST_WITH_ERROR_MESSAGE_light_extraExtraExtraLarge")
        } else {
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light)), named: "LIST_WITH_ERROR_MESSAGE_light")
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .dark)), named: "LIST_WITH_ERROR_MESSAGE_dark")
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light, contentSize: .extraExtraExtraLarge)), named: "LIST_WITH_ERROR_MESSAGE_light_extraExtraExtraLarge")
        }
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        let envValue = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"]
        return envValue == "1" || envValue == "true"
    }

    private func makeSUT() -> ListViewController {
        let controller = ListViewController()
        controller.loadViewIfNeeded()
        controller.tableView.separatorStyle = .none
        controller.tableView.showsVerticalScrollIndicator = false
        controller.tableView.showsHorizontalScrollIndicator = false
        return controller
    }

    private func emptyList() -> [CellController] {
        []
    }
}
