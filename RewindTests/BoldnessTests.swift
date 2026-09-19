//
//  BoldnessTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

@testable import Rewind
import Testing

struct BoldnessTests {
  private static let size = PlaneSize(width: 200, height: 16)
  private static let boldness: Float = 1.5
  private static let midtone: Float = 50
  private static let tintA: Float = 3
  private static let tintB: Float = 4
  private static let swing: Float = 10
  private static let midCast: Float = 0.85
  private static let midCastGain: Float = 1.25
  private static let atTopLeft: Float = 0.566255
  private static let atMiddle: Float = 0.605761
  private static let atBottomRight: Float = 0.883951
  private static let middleIndex = size.width * (size.height / 2) + size.width / 2
  private static let lastIndex = size.pixelCount - 1
  private static let tolerance: Float = 0.0005

  @Test func theWeightMapCarriesTheLightnessThroughTheBlur() {
    let weight = Boldness.lightnessWeight(Self.lightnessMosaic())

    #expect(abs(weight.values[0] - Self.atTopLeft) < Self.tolerance)
    #expect(abs(weight.values[Self.middleIndex] - Self.atMiddle) < Self.tolerance)
    #expect(abs(weight.values[Self.lastIndex] - Self.atBottomRight) < Self.tolerance)
  }

  @Test func halfwayThroughTheGuardHalfTheGainIsLeft() {
    let withdrawn = Boldness.effectiveBoldness(Self.boldness, castRatio: Self.midCast)

    #expect(abs(withdrawn - Self.midCastGain) < Self.tolerance)
  }

  @Test func aSingleTintKeepsTheColorTheModelPredicted() {
    let tinted = Self.planes { _ in (Self.tintA, Self.tintB) }

    let bolder = Boldness.apply(
      to: tinted,
      lightness: Self.flatLightness(),
      boldness: Self.boldness,
    )

    #expect(Boldness.castRatio(of: tinted) == 1)
    #expect(bolder.a == tinted.a)
    #expect(bolder.b == tinted.b)
  }

  @Test func aFrameThatLeansNowhereTakesTheWholeGain() {
    let balanced = Self.planes { column in
      (column < Self.size.width / 2 ? Self.swing : -Self.swing, 0)
    }

    let bolder = Boldness.apply(
      to: balanced,
      lightness: Self.flatLightness(),
      boldness: Self.boldness,
    )

    #expect(Boldness.castRatio(of: balanced) == 0)
    #expect(abs(bolder.a[0] - Self.swing * Self.boldness) < Self.tolerance)
    #expect(abs(bolder.a[Self.lastIndex] + Self.swing * Self.boldness) < Self.tolerance)
  }

  private static func lightnessMosaic() -> Plane<Float> {
    let values = (0..<size.pixelCount).map { index in
      Float((index % size.width + 13 * (index / size.width)) % 101)
    }
    return Plane(size: size, values: values)
  }

  private static func flatLightness() -> Plane<Float> {
    Plane(size: size, values: [Float](repeating: midtone, count: size.pixelCount))
  }

  private static func planes(_ value: (Int) -> (Float, Float)) -> ABPlanes {
    let pixels = (0..<size.pixelCount).map { value($0 % size.width) }
    return ABPlanes(size: size, a: pixels.map(\.0), b: pixels.map(\.1))
  }
}
