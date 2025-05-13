//
// Copyright © 2020 Essential Developer. All rights reserved.
//

import EssentialFeed
import Foundation

class NullStore {}

extension NullStore: FeedStore {
    func deleteCachedFeed() throws {}

    func insert(_: [LocalFeedImage], timestamp _: Date) throws {}

    func retrieve() throws -> CachedFeed? { .none }
}

extension NullStore: FeedImageDataStore {
    func insert(_: Data, for _: URL) throws {}

    func retrieve(dataForURL _: URL) throws -> Data? { .none }
}
