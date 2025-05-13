//
// Copyright © 2020 Essential Developer. All rights reserved.
//

import EssentialFeed
import XCTest

class ImageCommentsEndpointTests: XCTestCase {
    func test_imageComments_endpointURL() {
        let imageID = UUID(uuidString: "2239CBA2-CB35-4392-ADC0-24A37D38E010")!
        guard let baseURL = URL(string: "http://base-url.com") else {
            XCTFail("Failed to create URL")
            return
        }

        let received: URL = ImageCommentsEndpoint.get(imageID).url(baseURL: baseURL)
        guard let expected = URL(string: "http://base-url.com/v1/image/2239CBA2-CB35-4392-ADC0-24A37D38E010/comments") else {
            XCTFail("Failed to create expected URL")
            return
        }

        XCTAssertEqual(received, expected)
    }
}
