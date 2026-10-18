//
//  ThumbnailTitleStyle.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17. 10. 2026.
//

import SwiftUI
import UIKit
import VGSLFundamentals

enum ThumbnailTitleStyle: Equatable {
  case plain
  case dimmed(Float)
  case dark

  nonisolated static func measure(
    _ image: UIImage,
    widthToHeight: CGFloat,
    captionFraction: CGFloat,
  ) async -> ThumbnailTitleStyle {
    ThumbnailTitleStyle(
      backdrop: image,
      widthToHeight: widthToHeight,
      captionFraction: captionFraction
    )
  }

  private init(backdrop image: UIImage, widthToHeight: CGFloat, captionFraction: CGFloat) {
    guard image.imageOrientation == .up, let luminances = image.luminances(
      in: image.visibleTop(widthToHeight: widthToHeight, fraction: captionFraction),
    ) else {
      self = .plain
      return
    }
    let darkish = luminances.percentile(0.25)
    let lightish = luminances.percentile(0.75)
    if darkish >= 0.45 {
      self = .dark
    } else if lightish <= plainTitleMaxLuminance {
      self = .plain
    } else {
      self = .dimmed(
        (1 - Lab.gammaEncode(plainTitleMaxLuminance) / Lab.gammaEncode(lightish)).clamp(0...0.6),
      )
    }
  }

  var titleColor: Color {
    switch self {
    case .plain, .dimmed: .white
    case .dark: Color(white: 0.15)
    }
  }

  var dimming: Double {
    switch self {
    case let .dimmed(opacity): Double(opacity)
    case .plain, .dark: 0
    }
  }
}

private let plainTitleMaxLuminance: Float = 0.18

extension UIImage {
  fileprivate func visibleTop(widthToHeight: CGFloat, fraction: CGFloat) -> CGRect {
    guard let cgImage else { return .zero }
    let imageWidth = CGFloat(cgImage.width)
    let imageHeight = CGFloat(cgImage.height)
    let visible = if imageWidth / imageHeight > widthToHeight {
      CGRect(
        x: (imageWidth - imageHeight * widthToHeight) / 2,
        y: 0,
        width: imageHeight * widthToHeight,
        height: imageHeight,
      )
    } else {
      CGRect(
        x: 0,
        y: (imageHeight - imageWidth / widthToHeight) / 2,
        width: imageWidth,
        height: imageWidth / widthToHeight,
      )
    }
    return CGRect(
      x: visible.minX,
      y: visible.minY,
      width: visible.width,
      height: visible.height * fraction,
    ).integral
  }

  fileprivate func luminances(in rect: CGRect) -> [Float]? {
    guard let cropped = cgImage?.cropping(to: rect), rect.width > 0 else { return nil }
    let width = 24
    let height = max(1, Int((CGFloat(width) * rect.height / rect.width).rounded()))
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer in
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
              data: buffer.baseAddress,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
            ) else {
        return false
      }
      context.interpolationQuality = .medium
      context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return nil }
    return stride(from: 0, to: pixels.count, by: 4).map { index in
      Lab.luminance(
        r: Float(pixels[index]) / 255,
        g: Float(pixels[index + 1]) / 255,
        b: Float(pixels[index + 2]) / 255,
      )
    }
  }
}

extension [Float] {
  fileprivate func percentile(_ fraction: Float) -> Float {
    let sorted = sorted()
    return sorted[Int((Float(sorted.count - 1) * fraction).rounded())]
  }
}
