//
//  MapKit+Extensions.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 14.01.2023.
//

import MapKit

typealias Coordinate = CLLocationCoordinate2D
typealias Region = MKCoordinateRegion

extension Coordinate {
  static let zero = Coordinate(latitude: 0, longitude: 0)

  init(_ arr: [Double]) {
    guard arr.count == 2 else {
      assertionFailure("coordinate array should contain 2 values")
      self = .zero
      return
    }
    self.init(latitude: arr[0], longitude: arr[1])
  }

  var coords: (x: Double, y: Double) {
    (latitude, longitude)
  }

  func isAlmostEqual(to other: Self, e: Double = 0.01) -> Bool {
    latitude.isAlmostEqual(to: other.latitude, e: e)
      && longitude.isAlmostEqual(to: other.longitude, e: e)
  }

  func reversed() -> Coordinate {
    Coordinate(latitude: longitude, longitude: latitude)
  }

  // https://gist.github.com/missinglink/d0a085188a8eab2ca66db385bb7c023a
  func wrap() -> Coordinate {
    let quadrant = Int(abs(latitude) / 90) % 4
    let pole: Double = latitude > 0 ? 90 : -90
    let offset = latitude.truncatingRemainder(dividingBy: 90)

    var wrapped = self
    switch quadrant {
    case 0:
      wrapped.latitude = offset
    case 1:
      wrapped.latitude = pole - offset
      wrapped.longitude += 180
    case 2:
      wrapped.latitude = -offset
      wrapped.longitude += 180
    case 3:
      wrapped.latitude = -pole + offset
    default:
      assertionFailure("should not be reached")
    }

    if wrapped.longitude > 180 || wrapped.longitude < -180 {
      wrapped.longitude -= floor((wrapped.longitude + 180) / 360) * 360
    }

    return wrapped
  }
}

extension Coordinate: @retroactive Codable {
  private struct CoordinateCodableAdapter: Codable {
    var latitude: Double
    var longitude: Double
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(
      CoordinateCodableAdapter(
        latitude: latitude,
        longitude: longitude
      )
    )
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let adapter = try container.decode(CoordinateCodableAdapter.self)
    self.init(latitude: adapter.latitude, longitude: adapter.longitude)
  }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
  }
}

extension MKCoordinateSpan: @retroactive Equatable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.latitudeDelta == rhs.latitudeDelta && lhs.longitudeDelta == rhs.longitudeDelta
  }
}

extension MKCoordinateRegion: @retroactive Equatable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.span == rhs.span && lhs.center == rhs.center
  }

  public static let zero = MKCoordinateRegion(MKMapRect(x: 0, y: 0, width: 0, height: 0))
}

extension Region {
  private var geoJSONPoints: [Coordinate] {
    let halfLatitudeDelta = span.latitudeDelta / 2
    let halfLongitudeDelta = span.longitudeDelta / 2
    return [
      Coordinate(
        latitude: center.latitude - halfLatitudeDelta,
        longitude: center.longitude - halfLongitudeDelta
      ),
      Coordinate(
        latitude: center.latitude - halfLatitudeDelta,
        longitude: center.longitude + halfLongitudeDelta
      ),
      Coordinate(
        latitude: center.latitude + halfLatitudeDelta,
        longitude: center.longitude + halfLongitudeDelta
      ),
      Coordinate(
        latitude: center.latitude + halfLatitudeDelta,
        longitude: center.longitude - halfLongitudeDelta
      ),
      Coordinate(
        latitude: center.latitude - halfLatitudeDelta,
        longitude: center.longitude - halfLongitudeDelta
      ),
    ].map { $0.wrap() }
  }

  // server requires reverse order
  var geoJSONCoordinates: [[Double]] {
    geoJSONPoints.map { [$0.longitude, $0.latitude] }
  }
}

extension MKMapRect {
  var area: Double {
    width * height
  }

  func intersectFraction(_ other: MKMapRect) -> Double {
    guard area != 0 else { return 0 }
    let intersection = intersection(other)
    return intersection.area / area
  }
}

private func radians<T: FloatingPoint>(_ degrees: T) -> T {
  degrees * .pi / 180
}

extension FloatingPoint {
  func isAlmostEqual(to other: Self, e: Self = 0.01) -> Bool {
    abs(self - other) < e
  }
}
