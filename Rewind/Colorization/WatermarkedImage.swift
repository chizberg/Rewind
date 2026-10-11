//
//  WatermarkedImage.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import UIKit
import VGSL

struct WatermarkedImage: Equatable {
  var content: UIImage
  var watermark: UIImage?

  func stitched() async -> UIImage {
    let stripHeight = stripPixelHeight.rounded() / content.scale
    let watermarkHeight = watermark == nil ? 0 : stripHeight
    let size = CGSize(
      width: content.size.width,
      height: content.size.height + watermarkHeight + stripHeight,
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = content.scale
    format.opaque = true
    format.preferredRange = .standard
    let markRect = CGRect(
      x: 0,
      y: content.size.height + watermarkHeight,
      width: content.size.width,
      height: stripHeight,
    )
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      content.draw(at: .zero)
      watermark?.draw(in: CGRect(
        x: 0,
        y: content.size.height,
        width: content.size.width,
        height: watermarkHeight,
      ))
      context.cgContext.clip(to: markRect)
      drawColorizationMark(in: markRect, scale: content.scale)
    }
  }

  private var stripPixelHeight: CGFloat {
    if let watermark {
      content.size.width * content.scale * watermark.size.height / watermark.size.width
    } else {
      max(14, content.size.height * content.scale * 14 / 600)
    }
  }
}

private func drawColorizationMark(in rect: CGRect, scale: CGFloat) {
  UIColor.black.setFill()
  UIRectFill(rect)

  let indent = rect.height * 17 / 14
  let emojiSide = rect.height * 36 / 46
  let emojiRect = CGRect(
    x: rect.maxX - indent - emojiSide,
    y: rect.midY - emojiSide / 2,
    width: emojiSide,
    height: emojiSide,
  )
  drawEmoji("🌈", in: emojiRect)

  let plain = "colorized with " as NSString
  let painted = "rewind: history on a map" as NSString
  var font = UIFont.systemFont(ofSize: rect.height * 36 / 46, weight: .semibold)
  let availableWidth = emojiRect.minX - indent - rect.minX - indent
  let fullWidth = plain.size(withAttributes: [.font: font]).width
    + painted.size(withAttributes: [.font: font]).width
  if fullWidth > availableWidth {
    font = font.withSize(font.pointSize * availableWidth / fullWidth)
  }
  let origin = CGPoint(
    x: rect.minX + indent,
    y: rect.minY + rect.height * 36 / 46 - font.ascender,
  )
  plain.draw(at: origin, withAttributes: [.font: font, .foregroundColor: UIColor.white])
  let paintedOrigin = CGPoint(
    x: origin.x + plain.size(withAttributes: [.font: font]).width,
    y: origin.y,
  )
  drawInRainbow(painted, font: font, scale: scale, at: paintedOrigin)
}

private func drawEmoji(_ emoji: NSString, in rect: CGRect) {
  let font = UIFont.systemFont(ofSize: rect.height)
  let size = emoji.size(withAttributes: [.font: font])
  emoji.draw(
    at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
    withAttributes: [.font: font],
  )
}

private func drawInRainbow(_ text: NSString, font: UIFont, scale: CGFloat, at origin: CGPoint) {
  let colors: [UInt32] = [
    0xFF_38_3C_FF,
    0xFF_8D_28_FF,
    0xFF_CC_00_FF,
    0x34_C7_59_FF,
    0x00_88_FF_FF,
    0xCB_30_E0_FF
  ]
  let locations: [CGFloat] = [0.096, 0.26, 0.394, 0.553, 0.736, 0.904]
  guard let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: colors.map { VGSL.Color.colorWithHexCode($0).systemColor.cgColor } as CFArray,
    locations: locations,
  ) else { return }
  let size = text.size(withAttributes: [.font: font])
  let format = UIGraphicsImageRendererFormat()
  format.scale = scale
  format.opaque = false
  format.preferredRange = .standard
  let renderer = UIGraphicsImageRenderer(size: size, format: format)
  let glyphs = renderer.image { _ in
    text.draw(at: .zero, withAttributes: [.font: font, .foregroundColor: UIColor.white])
  }
  renderer.image { context in
    context.cgContext.drawLinearGradient(
      gradient,
      start: .zero,
      end: CGPoint(x: size.width, y: 0),
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation],
    )
    glyphs.draw(at: .zero, blendMode: .destinationIn, alpha: 1)
  }.draw(at: origin)
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
