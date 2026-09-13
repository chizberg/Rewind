//
//  ColorlessModel.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

@testable import Rewind

actor ColorlessModel: ColorizationModel {
  nonisolated let claheClip: Double
  private(set) var receivedGray: Plane<UInt8>?

  init(claheClip: Double) {
    self.claheClip = claheClip
  }

  func predict(gray: Plane<UInt8>) -> ABPlanes {
    receivedGray = gray
    let zeros = [Float](repeating: 0, count: gray.size.pixelCount)
    return ABPlanes(size: gray.size, a: zeros, b: zeros)
  }
}
