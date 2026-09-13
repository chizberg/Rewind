//
//  Plane.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import CoreGraphics

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

extension Plane<UInt8> {
  // The gray frame as the 8-bit RGB image a Core ML image input takes; the model applies its own
  // scale and bias to the bytes.
  // https://apple.github.io/coremltools/docs-guides/source/image-inputs.html#add-image-preprocessing-options
  func makeCGImage() throws -> CGImage {
    var bytes = [UInt8](repeating: 255, count: size.pixelCount * 4)
    for (i, value) in values.enumerated() {
      bytes[i * 4] = value
      bytes[i * 4 + 1] = value
      bytes[i * 4 + 2] = value
    }
    return try ColorizationHelpers.makeCGImage(bytes: bytes, size: size)
  }
}
