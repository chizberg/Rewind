//
//  PlaneConversion.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Accelerate
import UIKit

extension RGBPlanes {
  init(image: UIImage, maxSide: Int) throws {
    guard image.size.width > 0, image.size.height > 0 else {
      throw HandlingError("Image has zero size")
    }

    var source = image.cgImage
    if image.imageOrientation != .up || source == nil {
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      format.preferredRange = .standard
      source = UIGraphicsImageRenderer(size: image.size, format: format)
        .image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        .cgImage
    }

    guard let source else {
      throw HandlingError("Unable to read image for colorization")
    }
    try self.init(cgImage: source, maxSide: maxSide)
  }

  init(cgImage: CGImage, maxSide: Int) throws {
    let scale = min(1, Double(maxSide) / Double(max(cgImage.width, cgImage.height)))
    let width = max(1, Int((Double(cgImage.width) * scale).rounded()))
    let height = max(1, Int((Double(cgImage.height) * scale).rounded()))

    let space = cgImage.colorSpace?.model == .rgb
      ? cgImage.colorSpace!
      : CGColorSpaceCreateDeviceRGB()

    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: space,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
    ) else {
      throw HandlingError("Unable to create CGContext for colorization")
    }
    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = context.data else {
      throw HandlingError("CGContext has no data")
    }

    let size = PlaneSize(width: width, height: height)
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    func channel(offset: Int) -> [Float] {
      var values = [Float](repeating: 0, count: size.pixelCount)
      vDSP_vfltu8(bytes + offset, 4, &values, 1, UInt(size.pixelCount))
      return vDSP.multiply(1 / 255, values)
    }

    self.init(size: size, r: channel(offset: 0), g: channel(offset: 1), b: channel(offset: 2))
  }
}
