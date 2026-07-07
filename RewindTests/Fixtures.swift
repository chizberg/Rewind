//
//  Fixtures.swift
//  RewindTests
//
//  Loads real recorded PastVu API responses from RewindTests/Fixtures/ off disk
//  (works for local simulator test runs; avoids bundling into the test target).
//

import Foundation

enum Fixture {
  /// Absolute URL of a JSON file in RewindTests/Fixtures/, resolved relative to THIS source file.
  static func url(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/\(name)")
  }

  static func data(_ name: String) throws -> Data {
    try Data(contentsOf: url(name))
  }
}
