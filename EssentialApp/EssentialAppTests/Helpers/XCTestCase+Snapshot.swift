// Copyright 2019 Essential Developer. All rights reserved.

import UIKit
import XCTest

extension XCTestCase {
    func assert(snapshot: UIImage, named name: String, language: String, scheme: String, file: StaticString = #filePath, line: UInt = #line) {
        // `name` aquí es lo que viene de assertLoginSnapshotSync, ej "LOGIN_IDLE"
        let snapshotURL = makeSnapshotURL(named: name, language: language, scheme: scheme, file: file)
        let snapshotData = makeSnapshotData(for: snapshot, file: file, line: line)

        print("*********************************************************")
        print("[SNAPSHOT ASSERT] Received name: '\(name)'")
        print("[SNAPSHOT ASSERT] URL from makeSnapshotURL: \(snapshotURL.path)")
        print("[SNAPSHOT ASSERT] Will attempt to write to: \(snapshotURL.lastPathComponent)")
        print("*********************************************************")

        let recordMode = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true"

        print("[SNAPSHOT] Ruta destino: \(snapshotURL.path)")
        if FileManager.default.fileExists(atPath: snapshotURL.path) {
            print("[SNAPSHOT] ADVERTENCIA: El archivo ya existe y será sobrescrito: \(snapshotURL.lastPathComponent)")
        }

        if recordMode {
            do {
                try FileManager.default.createDirectory(
                    at: snapshotURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try snapshotData?.write(to: snapshotURL)
                print("[SNAPSHOT ASSERT] SUCCESSFULLY WROTE to: \(snapshotURL.path)")
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

    func makeSnapshotURL(named name: String, language: String, scheme: String, file: StaticString) -> URL {
        let fileManager = FileManager.default
        let snapshotsFolderURL = URL(fileURLWithPath: String(describing: file))
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots")

        let languageFolderURL = snapshotsFolderURL.appendingPathComponent(language)
        let schemeFolderURL = languageFolderURL.appendingPathComponent(scheme)

        // Intentar crear las carpetas explícitamente por si acaso
        try? fileManager.createDirectory(at: snapshotsFolderURL, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: languageFolderURL, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: schemeFolderURL, withIntermediateDirectories: true, attributes: nil)

        let finalFileName = "\(name).png"
        let snapshotURL = schemeFolderURL.appendingPathComponent(finalFileName)

        print("---------------------------------------------------------")
        print("[SNAPSHOT MAKE URL] Received name: '\(name)'")
        print("[SNAPSHOT MAKE URL] Language: '\(language)'")
        print("[SNAPSHOT MAKE URL] Scheme: '\(scheme)'")
        print("[SNAPSHOT MAKE URL] Intended final file name part: '\(name).png'")
        print("[SNAPSHOT MAKE URL] FINAL final file name: '\(finalFileName)'")
        print("[SNAPSHOT MAKE URL] FULL URL being returned: \(snapshotURL.path)")
        print("---------------------------------------------------------")

        return snapshotURL
    }

    private func makeSnapshotData(for snapshot: UIImage, file: StaticString, line: UInt) -> Data? {
        guard let data = snapshot.pngData() else {
            XCTFail("Failed to generate PNG data representation from snapshot", file: file, line: line)
            return nil
        }
        return data
    }
}
