//
//  WatermarkedImage.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import UIKit

struct WatermarkedImage: Equatable {
  var content: UIImage
  var watermark: UIImage?

  func stitched() async -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = content.scale
    format.opaque = true
    format.preferredRange = .standard
    let stripHeight = watermark.map { strip in
      let pixels = strip.size.height * content.size.width / strip.size.width * content.scale
      return pixels.rounded() / content.scale
    } ?? 0
    let size = CGSize(width: content.size.width, height: content.size.height + stripHeight)
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      content.draw(at: .zero)
      watermark?.draw(in: CGRect(
        x: 0,
        y: content.size.height,
        width: content.size.width,
        height: stripHeight,
      ))
    }
  }
}

func splitWatermark(
  from image: UIImage,
  watermarkHeight: Int,
  contentHeight: Int,
) async -> WatermarkedImage {
  guard let cgImage = image.cgImage,
        cgImage.height == contentHeight + watermarkHeight else {
    return WatermarkedImage(content: image, watermark: nil)
  }
  return await Task.detached(priority: .userInitiated) {
    func crop(y: Int, height: Int) -> UIImage? {
      cgImage.cropping(to: CGRect(
        x: 0,
        y: y,
        width: cgImage.width,
        height: height,
      )).map {
        UIImage(cgImage: $0, scale: image.scale, orientation: image.imageOrientation)
      }
    }
    guard let content = crop(y: 0, height: contentHeight),
          let watermark = crop(y: contentHeight, height: watermarkHeight) else {
      assertionFailure("Unable to crop an image of a size we have just checked")
      return WatermarkedImage(content: image, watermark: nil)
    }
    return WatermarkedImage(content: content, watermark: watermark)
  }.value
}
