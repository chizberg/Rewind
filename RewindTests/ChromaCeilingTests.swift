//
//  ChromaCeilingTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

@testable import Rewind
import Testing

struct ChromaCeilingTests {
  private static let size = PlaneSize(width: 401, height: 1)
  private static let boldness: Float = 1
  private static let ceiling: Float = 24
  private static let mixedPeak: Float = 100.07997
  private static let rampPeak: Float = 396
  private static let rampPeakPastTheGap: Float = 396.01
  private static let rampTop: Float = 400
  private static let cappedTop: Float = 24.242424
  private static let underTheCeiling: Float = 20
  private static let gapIndex = 7
  private static let lastIndex = size.pixelCount - 1
  private static let histogramTolerance: Float = 0.05
  private static let rankTolerance: Float = 0.01
  private static let tolerance: Float = 0.001

  @Test func theFrameIsMeasuredWhereNumpyMeasuresIt() {
    let mixed = Self.planes { index in
      (Float(index % 41) * 2.5, Float(index * 7 % 23))
    }

    let peak = ChromaCeiling.peakChroma(of: mixed)

    #expect(abs(peak - Self.mixedPeak) < Self.histogramTolerance)
  }

  @Test func aFrameOverTheCeilingComesBackUnderIt() {
    let ramp = Self.planes { index in (Float(index), 0) }

    let capped = ChromaCeiling.apply(to: ramp, boldness: Self.boldness)

    #expect(abs(ChromaCeiling.peakChroma(of: ramp) - Self.rampPeak) < Self.rankTolerance)
    #expect(abs(capped.a[Self.lastIndex] - Self.cappedTop) < Self.tolerance)
    #expect(abs(ChromaCeiling.peakChroma(of: capped) - Self.ceiling) < Self.tolerance)
  }

  @Test func aFrameUnderTheCeilingKeepsTheColorTheModelPredicted() {
    let ramp = Self.planes { index in
      (Float(index) * Self.underTheCeiling / Self.rampTop, 0)
    }

    let capped = ChromaCeiling.apply(to: ramp, boldness: Self.boldness)

    #expect(capped.a == ramp.a)
    #expect(capped.b == ramp.b)
  }

  @Test func aPixelWithoutAColorDoesNotTakeTheFrameWithIt() {
    let ramp = Self.planes { index in
      (index == Self.gapIndex ? Float.nan : Float(index), 0)
    }

    let peak = ChromaCeiling.peakChroma(of: ramp)

    #expect(abs(peak - Self.rampPeakPastTheGap) < Self.histogramTolerance)
  }

  private static func planes(_ value: (Int) -> (Float, Float)) -> ABPlanes {
    let pixels = (0..<size.pixelCount).map(value)
    return ABPlanes(size: size, a: pixels.map(\.0), b: pixels.map(\.1))
  }
}
