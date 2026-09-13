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
}
