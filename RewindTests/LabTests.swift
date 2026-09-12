//
//  LabTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

@testable import Rewind
import Testing

struct LabTests {
  @Test func lightnessFollowsTheOpenCVConvention() {
    let grays = RGBPlanes(
      size: PlaneSize(width: 4, height: 1),
      r: [0, 0.01, 0.5, 1],
      g: [0, 0.01, 0.5, 1],
      b: [0, 0.01, 0.5, 1],
    )

    let lightness = Lab.lightness(of: grays)

    #expect(abs(lightness.values[0]) < 0.01)
    #expect(abs(lightness.values[1] - 0.699) < 0.01)
    #expect(abs(lightness.values[2] - 53.387) < 0.01)
    #expect(abs(lightness.values[3] - 100) < 0.01)
  }

  @Test func lightnessComesFromLuminanceNotFromTheAverage() {
    let pixels = RGBPlanes(
      size: PlaneSize(width: 2, height: 1),
      r: [1, 0],
      g: [0, 1],
      b: [0, 0],
    )

    let lightness = Lab.lightness(of: pixels)

    #expect(abs(lightness.values[0] - 53.241) < 0.01)
    #expect(abs(lightness.values[1] - 87.735) < 0.01)
  }
}
