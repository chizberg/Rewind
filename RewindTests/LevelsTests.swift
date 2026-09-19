//
//  LevelsTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

@testable import Rewind
import Testing

struct LevelsTests {
  private static let size = PlaneSize(width: 401, height: 1)
  private static let lastIndex = size.pixelCount - 1
  private static let scaleBottom: Float = 0
  private static let scaleTop: Float = 100
  private static let rampLow: Float = 20
  private static let rampHigh: Float = 70
  private static let belowTheBand = 3
  private static let aboveTheBand = 397
  private static let insideTheBand = 5
  private static let insideTheBandValue: Float = 0.2551
  private static let middle = 200
  private static let middleValue: Float = 50
  private static let strayRampLow: Float = 30
  private static let strayRampHigh: Float = 60
  private static let pastTheStray = 100
  private static let pastTheStrayValue: Float = 24.4898
  private static let flatTone: Float = 40
  private static let tolerance: Float = 0.05

  @Test func theBandBetweenTheFirstAndTheLastPercentFillsTheScale() {
    let ramp = Self.plane { index in Self.ramp(index, Self.rampLow, Self.rampHigh) }

    let stretched = Levels.stretch(lightness: ramp)

    #expect(stretched.values[Self.belowTheBand] == Self.scaleBottom)
    #expect(stretched.values[Self.aboveTheBand] == Self.scaleTop)
    #expect(abs(stretched.values[Self.insideTheBand] - Self.insideTheBandValue) < Self.tolerance)
    #expect(abs(stretched.values[Self.middle] - Self.middleValue) < Self.tolerance)
  }

  @Test func aStrayPixelAtEachEndDoesNotSetTheRange() {
    let ramp = Self.plane { index in
      switch index {
      case 0: Self.scaleBottom
      case Self.lastIndex: Self.scaleTop
      default: Self.ramp(index, Self.strayRampLow, Self.strayRampHigh)
      }
    }

    let stretched = Levels.stretch(lightness: ramp)

    #expect(abs(stretched.values[Self.pastTheStray] - Self.pastTheStrayValue) < Self.tolerance)
    #expect(abs(stretched.values[Self.middle] - Self.middleValue) < Self.tolerance)
    #expect(stretched.values[0] == Self.scaleBottom)
    #expect(stretched.values[Self.lastIndex] == Self.scaleTop)
  }

  @Test func aFrameOfOneToneComesBackAsItIs() {
    let flat = Self.plane { _ in Self.flatTone }

    let stretched = Levels.stretch(lightness: flat)

    #expect(stretched.values == flat.values)
  }

  private static func ramp(_ index: Int, _ low: Float, _ high: Float) -> Float {
    low + (high - low) * Float(index) / Float(lastIndex)
  }

  private static func plane(_ value: (Int) -> Float) -> Plane<Float> {
    Plane(size: size, values: (0..<size.pixelCount).map(value))
  }
}
