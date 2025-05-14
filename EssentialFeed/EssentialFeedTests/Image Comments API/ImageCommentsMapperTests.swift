//
// Copyright 2020 Essential Developer. All rights reserved.
//

import EssentialFeed
import XCTest

class ImageCommentsMapperTests: XCTestCase {
    func test_map_throwsErrorOnNon2xxHTTPResponse() throws {
        let json: Data = makeItemsJSON([])
        let samples: [Int] = [199, 150, 300, 400, 500]

        try samples.forEach { code in
            XCTAssertThrowsError(
                try ImageCommentsMapper.map(json, from: HTTPURLResponse(statusCode: code))
            )
        }
    }

    func test_map_throwsErrorOn2xxHTTPResponseWithInvalidJSON() throws {
        let invalidJSON = Data("invalid json".utf8)
        let samples: [Int] = [200, 201, 250, 280, 299]

        try samples.forEach { code in
            XCTAssertThrowsError(
                try ImageCommentsMapper.map(invalidJSON, from: HTTPURLResponse(statusCode: code))
            )
        }
    }

    func test_map_deliversNoItemsOn2xxHTTPResponseWithEmptyJSONList() throws {
        let emptyListJSON: Data = makeItemsJSON([])
        let samples: [Int] = [200, 201, 250, 280, 299]

        try samples.forEach { code in
            let result: [ImageComment] = try ImageCommentsMapper.map(emptyListJSON, from: HTTPURLResponse(statusCode: code))

            XCTAssertEqual(result, [])
        }
    }

    func test_map_deliversItemsOn2xxHTTPResponseWithJSONItems() throws {
        let item1: (model: ImageComment, json: [String: Any]) = makeItem(
            id: UUID(),
            message: "a message",
            createdAt: (Date(timeIntervalSince1970: 1_598_627_222), "2020-08-28T15:07:02+00:00"),
            username: "a username"
        )

        let item2: (model: ImageComment, json: [String: Any]) = makeItem(
            id: UUID(),
            message: "another message",
            createdAt: (Date(timeIntervalSince1970: 1_577_881_882), "2020-01-01T12:31:22+00:00"),
            username: "another username"
        )

        let json: Data = makeItemsJSON([item1.json, item2.json])
        let samples: [Int] = [200, 201, 250, 280, 299]

        try samples.forEach { code in
            let result: [ImageComment] = try ImageCommentsMapper.map(json, from: HTTPURLResponse(statusCode: code))

            XCTAssertEqual(result, [item1.model, item2.model])
        }
    }

    // MARK: - Helpers

    private func makeItem(id: UUID, message: String, createdAt: (date: Date, iso8601String: String), username: String) -> (model: ImageComment, json: [String: Any]) {
        let item = ImageComment(id: id, message: message, createdAt: createdAt.date, username: username)

        let json: [String: Any] = [
            "id": id.uuidString,
            "message": message,
            "created_at": createdAt.iso8601String,
            "author": [
                "username": username
            ]
        ]

        return (item, json)
    }
}
