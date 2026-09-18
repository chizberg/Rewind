//
//  MagicBlur.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct MagicBlur {
  var image: UIImage
  var radius: Double
  var displayedSize: CGSize

  private static let context = CIContext()
  private static let sampleSide = 384.0

  func rendered() -> CGImage? {
    let scale = Self.sampleSide / max(image.size.width, image.size.height, 1)
    let sampleSize = CGSize(
      width: (image.size.width * scale).rounded(),
      height: (image.size.height * scale).rounded(),
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let sample = UIGraphicsImageRenderer(size: sampleSize, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: sampleSize))
    }
    guard let cgSample = sample.cgImage else { return nil }
    let source = CIImage(cgImage: cgSample)
    let blur = CIFilter.gaussianBlur()
    blur.inputImage = source.clampedToExtent()
    blur.radius = Float(radius * Self.sampleSide / max(
      displayedSize.width,
      displayedSize.height,
      1
    ))
    guard let output = blur.outputImage else { return nil }
    return Self.context.createCGImage(output, from: source.extent)
  }
}
