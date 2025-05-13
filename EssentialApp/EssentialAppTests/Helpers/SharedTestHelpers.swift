//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import EssentialFeed
import Foundation
import UIKit

func anyNSError() -> NSError {
    NSError(domain: "any error", code: 0)
}

func anyURL() -> URL {
    URL(string: "http://any-url.com")!
}

func anyData() -> Data {
    Data("any data".utf8)
}

// ADD: Helper para obtener datos PNG "estabilizados"
public func stabilizedPNGData(for color: UIColor) -> Data {
    let originalPngData = UIImage.make(withColor: color).pngData()!
    return UIImage(data: originalPngData)!.pngData()!
}

func uniqueFeed() -> [FeedImage] {
    [FeedImage(id: UUID(), description: "any", location: "any", url: anyURL())]
}

private class DummyView: ResourceView {
    func display(_: Any) {}
}

var loadError: String {
    LoadResourcePresenter<Any, DummyView>.loadError
}

var feedTitle: String {
    FeedPresenter.title
}

var commentsTitle: String {
    ImageCommentsPresenter.title
}
