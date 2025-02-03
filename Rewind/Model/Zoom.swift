//
//  Zoom.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 15.01.2023.
//

import MapKit

enum Model {} // namespace only

// https://leafletjs.com/examples/zoom-levels/
private func zoomFrom(_ delta: Double) -> Int {
  Int(2 + log2(180 / delta))
}

extension Region {
  var zoom: Int {
    let delta = min(span.latitudeDelta, span.longitudeDelta)
    return zoomFrom(delta).clamped(in: minZoom...maxZoom)
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
