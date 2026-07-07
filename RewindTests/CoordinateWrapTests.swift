//
//  CoordinateWrapTests.swift
//  RewindTests
//
//  Characterization tests for Coordinate.wrap() antimeridian / pole
//  normalization. Expected outputs are hand-worked from the algorithm and
//  asserted with a floating-point tolerance.
//  (Coordinate.reversed() is a trivial one-line lat/lon swap — not tested here;
//  its observable effect is pinned end-to-end by the reversed preview-coordinate
//  assertion in NetworkParsingTests.modelClusterReversesPreviewCoordinateOnly.)
//

import MapKit
@testable import Rewind
import Testing
import VGSL

struct CoordinateWrapTests {
  private func expectWrap(
    lat: Double,
    lon: Double,
    toLat: Double,
    toLon: Double,
    _ comment: Comment,
  ) {
    let wrapped = Coordinate(latitude: lat, longitude: lon).wrap()
    #expect(wrapped.latitude.isApproximatelyEqualTo(toLat), comment)
    #expect(wrapped.longitude.isApproximatelyEqualTo(toLon), comment)
  }

  @Test func inRangeIsIdentity() {
    expectWrap(lat: 55.75, lon: 37.62, toLat: 55.75, toLon: 37.62, "in-range identity")
  }

  @Test func longitudeOverflowWraps() {
    expectWrap(lat: 10.0, lon: 190.0, toLat: 10.0, toLon: -170.0, "lon overflow")
  }

  @Test func longitudeUnderflowWraps() {
    expectWrap(lat: 10.0, lon: -190.0, toLat: 10.0, toLon: 170.0, "lon underflow")
  }

  @Test func overNorthPoleFlipsLatAndLon() {
    expectWrap(lat: 100.0, lon: 20.0, toLat: 80.0, toLon: -160.0, "over north pole")
  }

  @Test func overSouthPoleFlipsLatAndLon() {
    expectWrap(lat: -100.0, lon: 20.0, toLat: -80.0, toLon: -160.0, "over south pole")
  }
}
