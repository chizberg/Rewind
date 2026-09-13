//
//  ABPlanes.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

import CoreML
import VGSL

// The a and b channels of CIE L*a*b* a colorization model predicts, in OpenCV's float units
// (-127...127).
// https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html#color_convert_rgb_lab
struct ABPlanes {
  // Width and height of both channels.
  var size: PlaneSize
  // a* of every pixel, row by row: negative towards green, positive towards red.
  var a: [Float]
  // b* of every pixel, row by row: negative towards blue, positive towards yellow.
  var b: [Float]

  // Both channels hold one value per pixel of `size`.
  init(size: PlaneSize, a: [Float], b: [Float]) {
    assert(a.count == size.pixelCount && b.count == size.pixelCount)
    self.size = size
    self.a = a
    self.b = b
  }

  // The graph's (1, 2, h, w) float16 output, a then b. Type and shape are checked: MLShapedArray
  // traps on a wrong type; its scalars honour strides, a raw buffer read does not.
  // https://developer.apple.com/documentation/coreml/mlshapedarrayprotocol/scalars
  init(_ array: MLMultiArray, size: PlaneSize) throws {
    guard array.dataType == .float16,
          array.shape == [1, 2, size.height, size.width].map(NSNumber.init(value:))
    else {
      throw HandlingError("The colorization model returned colors in an unexpected format")
    }
    let scalars = MLShapedArray<Float16>(array).scalars
    let count = size.pixelCount
    self.init(
      size: size,
      a: scalars[..<count].map(Float.init),
      b: scalars[count...].map(Float.init),
    )
  }

  // Keeps the top-left `target` of the model's ab, undoing padded(target:) (the reference's
  // ab[:, :, :uh, :uw]).
  // https://numpy.org/doc/stable/user/basics.indexing.html#slicing-and-striding
  func cropped(target: PlaneSize) -> ABPlanes {
    assert(target.width <= size.width && target.height <= size.height)
    func crop(_ values: [Float]) -> [Float] {
      (0..<target.height).flatMap { y in values[y * size.width..<y * size.width + target.width] }
    }
    return ABPlanes(size: target, a: crop(a), b: crop(b))
  }

  // Scales the model's ab to the gray frame's size, each pixel blended from its four nearest
  // source pixels (the reference's F.interpolate, mode="bilinear", align_corners=False).
  // https://docs.pytorch.org/docs/stable/generated/torch.nn.functional.interpolate.html
  func bilinearResized(target: PlaneSize) -> ABPlanes {
    let columns = Self.neighbors(from: size.width, to: target.width)
    let rows = Self.neighbors(from: size.height, to: target.height)
    func resize(_ values: [Float]) -> [Float] {
      var resized = [Float](repeating: 0, count: target.pixelCount)
      for y in 0..<target.height {
        let row = rows[y]
        let top = row.low * size.width
        let bottom = row.high * size.width
        for x in 0..<target.width {
          let column = columns[x]
          let upper = lerp(
            at: column.weight,
            between: values[top + column.low],
            values[top + column.high],
          )
          let lower = lerp(
            at: column.weight,
            between: values[bottom + column.low],
            values[bottom + column.high],
          )
          resized[y * target.width + x] = lerp(at: row.weight, between: upper, lower)
        }
      }
      return resized
    }
    return ABPlanes(size: target, a: resize(a), b: resize(b))
  }

  // The two source pixels an output pixel lies between along one axis.
  private struct Neighbors {
    // The source pixel at or before the output pixel's center.
    var low: Int
    // The next source pixel, or the same one at the far edge.
    var high: Int
    // How far the center is from low towards high, 0...1.
    var weight: Float
  }

  // Each output pixel's neighbors along one axis, a table computed once per axis, not per pixel.
  // Pixel centers sit half a pixel in; positions past an edge take the edge pixel
  // (align_corners=False).
  private static func neighbors(from source: Int, to destination: Int) -> [Neighbors] {
    let scale = Float(source) / Float(destination)
    return (0..<destination).map { index in
      let position = max(0, (Float(index) + 0.5) * scale - 0.5)
      let low = min(Int(position), source - 1)
      return Neighbors(low: low, high: min(low + 1, source - 1), weight: position - Float(low))
    }
  }
}
