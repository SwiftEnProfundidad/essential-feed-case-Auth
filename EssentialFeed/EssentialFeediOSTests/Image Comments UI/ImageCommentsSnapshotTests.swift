//
// Copyright 2020 Essential Developer. All rights reserved.
//

import EssentialFeed
import EssentialFeediOS
import XCTest

class ImageCommentsSnapshotTests: XCTestCase {
    func test_listWithComments() {
        let sut = makeSUT()

        sut.display(comments())

        if isRecording {
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light)), named: "IMAGE_COMMENTS_light")
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .dark)), named: "IMAGE_COMMENTS_dark")
            record(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light, contentSize: .extraExtraExtraLarge)), named: "IMAGE_COMMENTS_light_extraExtraExtraLarge")
        } else {
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light)), named: "IMAGE_COMMENTS_light")
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .dark)), named: "IMAGE_COMMENTS_dark")
            assert(snapshot: sut.snapshot(for: .iPhone16Pro(style: .light, contentSize: .extraExtraExtraLarge)), named: "IMAGE_COMMENTS_light_extraExtraExtraLarge")
        }
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        let envValue = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"]
        return envValue == "1" || envValue == "true"
    }

    private func makeSUT() -> ListViewController {
        let bundle = Bundle(for: ListViewController.self)
        let storyboard = UIStoryboard(name: "ImageComments", bundle: bundle)
        let controller = storyboard.instantiateInitialViewController() as! ListViewController
        controller.loadViewIfNeeded()
        controller.tableView.showsVerticalScrollIndicator = false
        controller.tableView.showsHorizontalScrollIndicator = false
        return controller
    }

    private func comments() -> [CellController] {
        commentControllers().map { CellController(id: UUID(), $0) }
    }

    private func commentControllers() -> [ImageCommentCellController] {
        [
            ImageCommentCellController(
                model: ImageCommentViewModel(
                    message: "The East Side Gallery is an open-air gallery in Berlin. It consists of a series of murals painted directly on a 1,316 m long remnant of the Berlin Wall, located near the centre of Berlin, on Mühlenstraße in Friedrichshain-Kreuzberg. The gallery has official status as a Denkmal, or heritage-protected landmark.",
                    date: "1000 years ago",
                    username: "a long long long long username"
                )
            ),
            ImageCommentCellController(
                model: ImageCommentViewModel(
                    message: "East Side Gallery\nMemorial in Berlin, Germany",
                    date: "10 days ago",
                    username: "a username"
                )
            ),
            ImageCommentCellController(
                model: ImageCommentViewModel(
                    message: "nice",
                    date: "1 hour ago",
                    username: "a."
                )
            )
        ]
    }
}
