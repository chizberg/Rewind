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

  @Test func labBackToRGBFollowsOpenCVOnBothSegmentsAndClampsOutOfGamutChannels() {
    let size = PlaneSize(width: 6, height: 1)
    let lightness = Plane<Float>(size: size, values: [50, 50, 80, 20, 100, 6])
    let ab = ABPlanes(size: size, a: [0, 40, -30, 10, 0, 3], b: [0, 20, 60, -40, 0, 8])

    let rgb = Lab.rgb(lightness: lightness, ab: ab)

    let expected: [Float] = [
      0.4663, 0.7371, 0.6957, 0, 1, 0.1109,
      0.4663, 0.3465, 0.8285, 0.1859, 1, 0.0675,
      0.4663, 0.3417, 0.3081, 0.4220, 1, 0.0099,
    ]
    for (measured, reference) in zip(rgb.r + rgb.g + rgb.b, expected) {
      #expect(abs(measured - reference) < 0.002)
    }
  }
}
