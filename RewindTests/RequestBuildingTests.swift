//
//  RequestBuildingTests.swift
//  RewindTests
//
//  Pins the non-obvious part of Network.Request URL building: the getByBounds `params` JSON
//  is inspected by DECODING the query item (order-independent). The one thing a naive port
//  gets silently wrong is the extra array level that nests the region's ring into a valid
//  GeoJSON Polygon — forget it and the server returns nothing. Also covers the image URL's
//  garbage-query stripping.
//

import Foundation
import MapKit
@testable import Rewind
import Testing
import UIKit

// A real region's ring (closed 5-point [lon, lat] loop) — exactly what the app feeds byBounds.
private let region = Region(
  center: Coordinate(latitude: 50.08, longitude: 14.42),
  span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.07),
)
private let ring = region.geoJSONCoordinates

// Test-local mirror of the private RawParams in Request.swift. Decodable ignores the extra keys.
private struct ParamsMirror: Decodable {
  struct Geometry: Decodable {
    let coordinates: [[[Double]]]
  }

  let geometry: Geometry
}

struct RequestBuildingTests {
  private func decodeByBoundsParams() throws -> ParamsMirror {
    let request: Network.Request<([Network.Image], [Network.Cluster])> = .byBounds(
      zoom: 13,
      coordinates: ring,
      startAt: 0,
      yearRange: 1826...2000,
      isPainting: false,
    )
    let urlRequest = try request.makeURLRequest()
    let url = try #require(urlRequest.url)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let paramsString = try #require(components.queryItems?.first { $0.name == "params" }?.value)
    return try JSONDecoder().decode(ParamsMirror.self, from: Data(paramsString.utf8))
  }

  // MARK: - getByBounds geometry

  @Test func byBoundsWrapsRingInPolygonCoordinates() throws {
    // GeoJSON Polygon coordinates are an array of linear rings: the ring must be nested ONE
    // level deeper. Forgetting the wrap sends a malformed polygon and the server returns nothing.
    let params = try decodeByBoundsParams()
    #expect(params.geometry.coordinates.count == 1)
    #expect(params.geometry.coordinates[0] == ring)
  }

  // MARK: - image URL query stripping

  @Test func imageURLStripsGarbageQuery() throws {
    // `file` paths carry garbage query params (`?s=...`, API quirk #4). They must be
    // dropped when building the image URL or the CDN request 404s.
    let request: Network.Request<UIImage> = .image(
      path: "q/q/p/qqp52d1i1jn4qndllt.jpg?s=81293f61a6",
      quality: .low,
    )
    let url = try #require(try request.makeURLRequest().url)
    #expect(url.query == nil)
    #expect(url.absoluteString == "https://img.pastvu.com/s/q/q/p/qqp52d1i1jn4qndllt.jpg")
  }
}
