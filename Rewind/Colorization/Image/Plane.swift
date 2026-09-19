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

extension Plane<Float> {
  // numpy.percentile's default linear interpolation, read off a histogram instead of a sorted
  // copy: the rank the percentile asks for falls between two of the sorted values, and the answer
  // is the point between them. Sorting three million floats to read one of them costs about forty
  // times what binning them does (380 ms against 9 at -O). On a frame of that many pixels the two
  // sorted values the rank falls between land in the same bin, and the answer then comes out
  // within a bin's width of the exact one; on a handful of far apart values it would not. Values
  // that are not finite are left out, both because the bin index of one cannot be computed at all
  // and because a single stray pixel must not decide the answer for the whole frame.
  // https://numpy.org/doc/stable/reference/generated/numpy.percentile.html
  func percentile(_ percent: Double, bins binCount: Int) -> Float {
    var minimum = Float.greatestFiniteMagnitude
    var maximum = -Float.greatestFiniteMagnitude
    var count = 0
    for value in values where value.isFinite {
      minimum = min(minimum, value)
      maximum = max(maximum, value)
      count += 1
    }
    guard count > 0 else {
      return 0
    }
    guard maximum > minimum else {
      return minimum
    }

    let width = (maximum - minimum) / Float(binCount)
    var bins = [Int](repeating: 0, count: binCount)
    for value in values where value.isFinite {
      bins[min(binCount - 1, Int((value - minimum) / width))] += 1
    }

    // The rank sits at p/100 of the way from the first sorted value to the last, and inside the
    // bin that holds it the values are taken to be evenly spread.
    let target = percent / 100 * Double(count - 1)
    var below = 0
    for (index, bin) in bins.enumerated() {
      guard Double(below + bin) > target else {
        below += bin
        continue
      }
      let position = Float((target - Double(below)) / Double(bin))
      return minimum + (Float(index) + position) * width
    }
    return maximum
  }
}
