//
//  Zoom.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 15.01.2023.
//

import MapKit
import VGSL

/// https://leafletjs.com/examples/zoom-levels/
func zoom(region: Region, mapSize: CGSize) -> Int {
  let delta = min(region.span.latitudeDelta, region.span.longitudeDelta)
  return Int(
    (log2(360 / delta)
      + adjustment(mapSize: mapSize)
    ).rounded(.toNearestOrAwayFromZero)
  ).clamp(3...19)
}

func delta(zoom: Int, mapSize: CGSize) -> Double {
  360 / pow(2, Double(zoom) - adjustment(mapSize: mapSize))
}

private func adjustment(mapSize: CGSize) -> Double {
  lerp(at: min(mapSize.width, mapSize.height), in: adjustments)
}

private let adjustments = NonEmptyArray([
  (375.0, 0.65), // iPhone SE (3rd gen) width
  (430.0, 0.8), // iPhone 15 Pro Max width
  (1024.0, 1.5), // iPad Pro 13' width
].map { InterpolationPoint($0, $1) })!

extension Double: Interpolatable {
  func lerp(at: CGFloat, between lhs: Double, _ rhs: Double) -> Double {
    Rewind.lerp(at: at, between: lhs, rhs)
  }
}

extension Region {
  init(
    center: Coordinate,
    zoom: Int,
    mapSize: CGSize
  ) {
    let delta = delta(zoom: zoom, mapSize: mapSize)
    self.init(
      center: center,
      span: MKCoordinateSpan(
        latitudeDelta: delta,
        longitudeDelta: delta
      )
    )
  }
}
