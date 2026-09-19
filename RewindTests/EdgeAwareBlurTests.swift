//
//  EdgeAwareBlurTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

@testable import Rewind
import Testing

struct EdgeAwareBlurTests {
  private static let size = PlaneSize(width: 1600, height: 16)
  private static let boundary = 800
  private static let step: Float = 5
  private static let leftOfBoundary = size.width * (size.height / 2) + boundary - 1
  private static let rightOfBoundary = size.width * (size.height / 2) + boundary
  private static let smoothedAcrossFlatLightness: Float = 0.7095
  private static let heldByTheLightnessEdge: Float = 4.8411
  private static let tolerance: Float = 0.01

  @Test func aFlatColorIsUnchangedWhateverTheLightness() throws {
    let lightness = Plane(
      size: Self.size,
      values: (0..<Self.size.pixelCount).map { Float($0 % 100) },
    )
    let ab = ABPlanes(
      size: Self.size,
      a: [Float](repeating: 12, count: Self.size.pixelCount),
      b: [Float](repeating: -30, count: Self.size.pixelCount),
    )

    let smoothed = try EdgeAwareBlur.apply(to: ab, lightness: lightness)

    #expect(smoothed.a.allSatisfy { abs($0 - 12) < 0.001 })
    #expect(smoothed.b.allSatisfy { abs($0 + 30) < 0.001 })
  }

  @Test func aColorStepIsSmoothedAwayWhereTheLightnessIsFlat() throws {
    let smoothed = try EdgeAwareBlur.apply(
      to: Self.colorStep(),
      lightness: Self.lightness(left: 50, right: 50),
    )

    let left = smoothed.a[Self.leftOfBoundary]
    let right = smoothed.a[Self.rightOfBoundary]
    #expect(abs(left - Self.smoothedAcrossFlatLightness) < Self.tolerance)
    #expect(abs(right + Self.smoothedAcrossFlatLightness) < Self.tolerance)
  }

  @Test func aLightnessEdgeKeepsTheColorStepOnItsOwnSide() throws {
    let smoothed = try EdgeAwareBlur.apply(
      to: Self.colorStep(),
      lightness: Self.lightness(left: 20, right: 80),
    )

    let left = smoothed.a[Self.leftOfBoundary]
    let right = smoothed.a[Self.rightOfBoundary]
    #expect(abs(left - Self.heldByTheLightnessEdge) < Self.tolerance)
    #expect(abs(right + Self.heldByTheLightnessEdge) < Self.tolerance)
  }

  private static func colorStep() -> ABPlanes {
    ABPlanes(
      size: size,
      a: byColumn { $0 < boundary ? step : -step },
      b: [Float](repeating: 0, count: size.pixelCount),
    )
  }

  private static func lightness(left: Float, right: Float) -> Plane<Float> {
    Plane(size: size, values: byColumn { $0 < boundary ? left : right })
  }

  private static func byColumn(_ value: (Int) -> Float) -> [Float] {
    (0..<size.pixelCount).map { value($0 % size.width) }
  }
}
