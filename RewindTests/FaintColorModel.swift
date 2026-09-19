//
//  FaintColorModel.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

@testable import Rewind

actor FaintColorModel: ColorizationModel {
  static let chroma: Float = 6

  nonisolated let claheClip: Double = 1
  nonisolated let boldness: Float = 1.5

  func predict(gray: Plane<UInt8>) -> ABPlanes {
    let a = (0..<gray.size.pixelCount).map { index in
      index % gray.size.width < gray.size.width / 2 ? Self.chroma : -Self.chroma
    }
    return ABPlanes(
      size: gray.size,
      a: a,
      b: [Float](repeating: 0, count: gray.size.pixelCount),
    )
  }
}
