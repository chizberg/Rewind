//
//  ABPlanes.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

import CoreML

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
}
