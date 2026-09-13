//
//  ColorizationHelpers.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import CoreGraphics
import Foundation
import VGSL

// Helpers shared by the colorization pipeline's stages, kept out of the app's global scope.
enum ColorizationHelpers {
  // OpenCV's BORDER_REFLECT_101: an index past the edge folds back without repeating the edge
  // pixel, abcd -> dcb|abcd|cba. A single pixel has nothing to fold into, it is the answer.
  // https://docs.opencv.org/4.x/d2/de8/group__core__array.html#ga247f571aa6244827d3d798f13892da58
  static func mirroredIndex(_ index: Int, limit: Int) -> Int {
    guard limit > 1 else { return 0 }
    let period = 2 * limit - 2
    var i = index % period
    if i < 0 { i += period }
    return i < limit ? i : period - i
  }

  // A 0...1 channel as a byte, halves away from zero. cv2 rounds them to even, but a gamma curve
  // almost never lands on an exact half: the parity gray frame comes out identical either way.
  static func byte(sRGB value: Float) -> UInt8 {
    UInt8((value.clamp(0...1) * 255).rounded())
  }

  // 8-bit RGB pixels, row by row with a skipped fourth byte each, as a CGImage: the gray frame a
  // Core ML image input takes and the colorized photo are both handed over this way.
  // https://developer.apple.com/documentation/coregraphics/cgimagealphainfo/noneskiplast
  static func makeCGImage(bytes: [UInt8], size: PlaneSize) throws -> CGImage {
    assert(bytes.count == size.pixelCount * 4)
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let image = CGImage(
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
          )
    else {
      throw HandlingError("Unable to make an image for colorization")
    }
    return image
  }
}
