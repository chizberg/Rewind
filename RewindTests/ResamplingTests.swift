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
}
