//
//  Zoom.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 15.01.2023.
//

import MapKit
import VGSL

// https://leafletjs.com/examples/zoom-levels/
func zoom(region: Region, mapSize: CGSize) -> Int {
  let delta = min(region.span.latitudeDelta, region.span.longitudeDelta)
  return Int(
    log2(360 / delta).rounded(.toNearestOrAwayFromZero)
      + adjustment(mapSize: mapSize)
  ).clamp(3...19)
}

func delta(zoom: Int, mapSize: CGSize) -> Double {
  360 / pow(2, Double(zoom) - adjustment(mapSize: mapSize))
}

private func adjustment(mapSize: CGSize) -> Double {
  let x = min(mapSize.width, mapSize.height)
  let (x1, y1) = (375.0, 0.7) // min adjustment for small screens
  let (x2, y2) = (1024.0, 1.5) // max adjustment for large screens
  return (y2 - y1) / (x2 - x1) * (x - x1) + y1
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
