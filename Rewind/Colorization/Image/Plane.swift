//
//  Plane.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Foundation

struct Plane<Value> {
  var size: PlaneSize
  var values: [Value]

  init(size: PlaneSize, values: [Value]) {
    assert(values.count == size.pixelCount)
    self.size = size
    self.values = values
  }

  func map<T>(_ transform: (Value) -> T) -> Plane<T> {
    Plane<T>(size: size, values: values.map(transform))
  }
}

struct PlaneSize: Equatable {
  var width: Int
  var height: Int

  var pixelCount: Int { width * height }
}

struct RGBPlanes {
  var size: PlaneSize
  var r: [Float]
  var g: [Float]
  var b: [Float]

  init(size: PlaneSize, r: [Float], g: [Float], b: [Float]) {
    assert(r.count == size.pixelCount && g.count == size.pixelCount && b.count == size.pixelCount)
    self.size = size
    self.r = r
    self.g = g
    self.b = b
  }
}
