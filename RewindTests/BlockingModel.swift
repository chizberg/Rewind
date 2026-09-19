//
//  BlockingModel.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

@testable import Rewind

@MainActor
final class BlockingModel: ColorizationModel {
  nonisolated let claheClip = 1.0
  nonisolated let boldness: Float = 1

  private(set) var isPredicting = false
  private(set) var wasCancelled = false
  private var release: CheckedContinuation<Void, Never>?

  func predict(gray: Plane<UInt8>) async -> ABPlanes {
    isPredicting = true
    await withCheckedContinuation { release = $0 }
    isPredicting = false
    wasCancelled = Task.isCancelled
    let zeros = [Float](repeating: 0, count: gray.size.pixelCount)
    return ABPlanes(size: gray.size, a: zeros, b: zeros)
  }

  func finishPrediction() {
    release?.resume()
    release = nil
  }
}
