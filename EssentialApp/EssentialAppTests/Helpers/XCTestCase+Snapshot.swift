// Copyright © 2019 Essential Developer. All rights reserved.

import UIKit
import XCTest

extension XCTestCase {
    func assert(snapshot: UIImage, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let snapshotURL = makeSnapshotURL(named: name, file: file)
        let snapshotData = makeSnapshotData(for: snapshot, file: file, line: line)

        let recordMode = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true"

        if recordMode {
            do {
                try FileManager.default.createDirectory(
                    at: snapshotURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                try snapshotData?.write(to: snapshotURL)
            } catch {
                XCTFail("Failed to record snapshot with error: \(error)", file: file, line: line)
            }
        } else {
            guard let storedSnapshotData = try? Data(contentsOf: snapshotURL) else {
                XCTFail("Failed to load stored snapshot at URL: \(snapshotURL). Use the `record` method (by setting RECORD_SNAPSHOTS=true environment variable) to store a snapshot before asserting.", file: file, line: line)
                return
            }

            if snapshotData != storedSnapshotData {
                let temporarySnapshotURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                    .appendingPathComponent(snapshotURL.lastPathComponent)

                try? snapshotData?.write(to: temporarySnapshotURL)

                XCTFail("New snapshot does not match stored snapshot. New snapshot URL: \(temporarySnapshotURL), Stored snapshot URL: \(snapshotURL)", file: file, line: line)
            }
        }
    }

    func makeSnapshotURL(named name: String, file: StaticString) -> URL {
        URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")
            .appendingPathComponent("\(name).png")
    }

    private func makeSnapshotData(for snapshot: UIImage, file: StaticString, line: UInt) -> Data? {
        guard let data = snapshot.pngData() else {
            XCTFail("Failed to generate PNG data representation from snapshot", file: file, line: line)
            return nil
        }
        return data
    }
}
