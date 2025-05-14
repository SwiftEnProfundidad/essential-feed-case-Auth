//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import EssentialFeed
import Foundation

class InMemoryFeedStore {
    private(set) var feedCache: CachedFeed?
    private var feedImageDataCache: [URL: Data] = [:]
    private let queue = DispatchQueue(label: "\(InMemoryFeedStore.self)Queue", qos: .userInitiated, attributes: .concurrent)

    private init(feedCache: CachedFeed? = nil) {
        self.feedCache = feedCache
    }
}

extension InMemoryFeedStore: FeedStore {
    func deleteCachedFeed() throws {
        queue.sync(flags: .barrier) {
            self.feedCache = nil
        }
    }

    func insert(_ feed: [LocalFeedImage], timestamp: Date) throws {
        queue.sync(flags: .barrier) {
            self.feedCache = CachedFeed(feed: feed, timestamp: timestamp)
        }
    }

    func retrieve() throws -> CachedFeed? {
        var result: CachedFeed?
        queue.sync {
            result = self.feedCache
        }
        return result
    }
}

extension InMemoryFeedStore: FeedImageDataStore {
    func insert(_ data: Data, for url: URL) throws {
        queue.sync(flags: .barrier) {
            self.feedImageDataCache[url] = data
        }
    }

    func retrieve(dataForURL url: URL) throws -> Data? {
        var result: Data?
        queue.sync {
            result = self.feedImageDataCache[url]
        }
        return result
    }
}

extension InMemoryFeedStore {
    static var empty: InMemoryFeedStore {
        InMemoryFeedStore()
    }

    static var withExpiredFeedCache: InMemoryFeedStore {
        InMemoryFeedStore(feedCache: CachedFeed(feed: [], timestamp: Date.distantPast))
    }

    static var withNonExpiredFeedCache: InMemoryFeedStore {
        InMemoryFeedStore(feedCache: CachedFeed(feed: [], timestamp: Date()))
    }
}
