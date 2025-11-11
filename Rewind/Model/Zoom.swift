//
//  Zoom.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 15.01.2023.
//

import MapKit

enum Model {} // namespace only

// https://leafletjs.com/examples/zoom-levels/
private func zoom(delta: Double) -> Int {
  Int((2 + log2(180 / delta)).rounded(.toNearestOrAwayFromZero))
}

private func delta(zoom: Int) -> Double {
  180 / pow(2, Double(zoom - 2))
}

extension Region {
  var zoom: Int {
    let delta = min(span.latitudeDelta, span.longitudeDelta)
    return Rewind.zoom(delta: delta).clamped(in: minZoom...maxZoom)
  }

  init(center: Coordinate, zoom: Int) {
    let delta = delta(zoom: zoom)
    self.init(
      center: center,
      span: MKCoordinateSpan(
        latitudeDelta: delta,
        longitudeDelta: delta
      )
    )
  }
}

extension Comparable {
  func clamped(in range: ClosedRange<Self>) -> Self {
    let lowerBound = range.lowerBound
    let upperBound = range.upperBound

    return min(upperBound, max(lowerBound, self))
  }
}

private let minZoom = 3
private let maxZoom = 19
