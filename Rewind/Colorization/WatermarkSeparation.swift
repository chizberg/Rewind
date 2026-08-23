//
//  WatermarkSeparation.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import UIKit

struct WatermarkedImage: Equatable {
  var content: UIImage
  var watermark: UIImage?
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
