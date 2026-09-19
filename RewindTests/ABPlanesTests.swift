//
//  ABPlanesTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

@testable import Rewind
import Testing

struct ABPlanesTests {
  @Test func croppingKeepsTheTopLeftCorner() {
    let planes = ABPlanes(
      size: PlaneSize(width: 4, height: 3),
      a: [
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
      ],
      b: [
        -10, -20, -30, -40,
        -50, -60, -70, -80,
        -90, -100, -110, -120,
      ],
    )

    let cropped = planes.cropped(target: PlaneSize(width: 3, height: 2))

    #expect(cropped.size == PlaneSize(width: 3, height: 2))
    #expect(cropped.a == [1, 2, 3, 5, 6, 7])
    #expect(cropped.b == [-10, -20, -30, -50, -60, -70])
  }

  @Test func bilinearUpscalingBlendsFromHalfPixelCenters() {
    let planes = ABPlanes(
      size: PlaneSize(width: 2, height: 2),
      a: [
        0, 100,
        100, 0,
      ],
      b: [
        -40, 20,
        60, -80,
      ],
    )

    let resized = planes.bilinearResized(target: PlaneSize(width: 4, height: 4))

    #expect(resized.size == PlaneSize(width: 4, height: 4))
    #expect(resized.a == [
      0, 25, 75, 100,
      25, 37.5, 62.5, 75,
      75, 62.5, 37.5, 25,
      100, 75, 25, 0,
    ])
    #expect(resized.b == [
      -40, -25, 5, 20,
      -15, -12.5, -7.5, -5,
      35, 12.5, -32.5, -55,
      60, 25, -45, -80,
    ])
  }

  @Test func bilinearResizingKeepsTheAxesApart() {
    let planes = ABPlanes(
      size: PlaneSize(width: 3, height: 2),
      a: [
        0, 10, 20,
        30, 40, 50,
      ],
      b: [
        -5, -15, -25,
        35, 45, 55,
      ],
    )

    let resized = planes.bilinearResized(target: PlaneSize(width: 6, height: 8))

    #expect(resized.size == PlaneSize(width: 6, height: 8))
    #expect(resized.a == [
      0, 2.5, 7.5, 12.5, 17.5, 20,
      0, 2.5, 7.5, 12.5, 17.5, 20,
      3.75, 6.25, 11.25, 16.25, 21.25, 23.75,
      11.25, 13.75, 18.75, 23.75, 28.75, 31.25,
      18.75, 21.25, 26.25, 31.25, 36.25, 38.75,
      26.25, 28.75, 33.75, 38.75, 43.75, 46.25,
      30, 32.5, 37.5, 42.5, 47.5, 50,
      30, 32.5, 37.5, 42.5, 47.5, 50,
    ])
    #expect(resized.b == [
      -5, -7.5, -12.5, -17.5, -22.5, -25,
      -5, -7.5, -12.5, -17.5, -22.5, -25,
      0, -1.875, -5.625, -9.375, -13.125, -15,
      10, 9.375, 8.125, 6.875, 5.625, 5,
      20, 20.625, 21.875, 23.125, 24.375, 25,
      30, 31.875, 35.625, 39.375, 43.125, 45,
      35, 37.5, 42.5, 47.5, 52.5, 55,
      35, 37.5, 42.5, 47.5, 52.5, 55,
    ])
  }
}
