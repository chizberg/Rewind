//
//  ResamplingTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

@testable import Rewind
import Testing

struct ResamplingTests {
  @Test func wholeBlocksAreAveraged() {
    let plane = Plane<UInt8>(
      size: PlaneSize(width: 4, height: 4),
      values: Array(stride(from: 0, through: 240, by: 16)),
    )

    let resized = plane.resized(target: PlaneSize(width: 2, height: 2))

    #expect(resized.size == PlaneSize(width: 2, height: 2))
    #expect(resized.values == [40, 72, 168, 200])
  }

  @Test func partlyCoveredPixelsCountByOverlap() {
    let plane = Plane<UInt8>(
      size: PlaneSize(width: 5, height: 3),
      values: [
        0, 200, 50, 255, 100,
        30, 90, 180, 10, 220,
        250, 40, 120, 70, 160,
      ],
    )

    let resized = plane.resized(target: PlaneSize(width: 3, height: 2))

    #expect(resized.size == PlaneSize(width: 3, height: 2))
    #expect(resized.values == [71, 123, 153, 129, 105, 128])
  }

  @Test func mirroredIndexFoldsBackWithoutRepeatingTheEdge() {
    #expect((-7...10).map { ColorizationHelpers.mirroredIndex($0, limit: 4) } == [
      1, 0, 1, 2, 3, 2,
      1, 0, 1, 2, 3, 2,
      1, 0, 1, 2, 3, 2,
    ])
    #expect((-2...3).map { ColorizationHelpers.mirroredIndex($0, limit: 1) } == [0, 0, 0, 0, 0, 0])
  }

  @Test func paddingMirrorsTheFramePastItsEdges() {
    let plane = Plane<UInt8>(size: PlaneSize(width: 4, height: 3), values: Array(1...12))

    let padded = plane.padded(target: PlaneSize(width: 9, height: 5))

    #expect(padded.size == PlaneSize(width: 9, height: 5))
    #expect(padded.values == [
      1, 2, 3, 4, 3, 2, 1, 2, 3,
      5, 6, 7, 8, 7, 6, 5, 6, 7,
      9, 10, 11, 12, 11, 10, 9, 10, 11,
      5, 6, 7, 8, 7, 6, 5, 6, 7,
      1, 2, 3, 4, 3, 2, 1, 2, 3,
    ])
  }
}
