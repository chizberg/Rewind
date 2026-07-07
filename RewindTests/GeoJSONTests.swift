//
//  GeoJSONTests.swift
//  RewindTests
//
//  Characterization tests for Region.geoJSONCoordinates: the [lon, lat] swap,
//  the 5-point closed ring, and the corner ordering (center ± half-span).
//

import MapKit
@testable import Rewind
import Testing
import VGSL

struct GeoJSONTests {
  private func makeCoordinates() -> [[Double]] {
    let region = Region(
      center: Coordinate(latitude: 50, longitude: 14),
      span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.4),
    )
    return region.geoJSONCoordinates
  }

  @Test func ringHasFiveClosedPoints() {
    let coords = makeCoordinates()
    #expect(coords.count == 5)
    // Each point is [lon, lat] — exactly 2 elements.
    for point in coords {
      #expect(point.count == 2)
    }
    // Closed ring: first == last.
    #expect(coords[0][0].isApproximatelyEqualTo(coords[4][0]))
    #expect(coords[0][1].isApproximatelyEqualTo(coords[4][1]))
  }

  @Test func cornerOrderAndLonLatSwap() {
    let coords = makeCoordinates()
    let expected: [[Double]] = [
      [13.8, 49.9],
      [14.2, 49.9],
      [14.2, 50.1],
      [13.8, 50.1],
      [13.8, 49.9],
    ]
    for (point, exp) in zip(coords, expected) {
      #expect(point[0].isApproximatelyEqualTo(exp[0])) // longitude first
      #expect(point[1].isApproximatelyEqualTo(exp[1])) // latitude second
    }
  }
}
