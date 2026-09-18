//
//  MagicDot.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import UIKit

struct MagicDot {
  var brightness: Double

  static let diameter = 4.0

  func rendered() -> CGImage? {
    let format = UIGraphicsImageRendererFormat()
    format.preferredRange = .extended
    let size = CGSize(width: Self.diameter, height: Self.diameter)
    let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ??
      CGColorSpaceCreateDeviceRGB()
    let components: [CGFloat] = [brightness, brightness, brightness, 1]
    let clear: [CGFloat] = [brightness, brightness, brightness, 0]
    guard
      let center = CGColor(colorSpace: colorSpace, components: components),
      let edge = CGColor(colorSpace: colorSpace, components: clear),
      let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [center, edge] as CFArray,
        locations: [0, 1]
      )
    else { return nil }
    let middle = CGPoint(x: size.width / 2, y: size.height / 2)
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      context.cgContext.drawRadialGradient(
        gradient,
        startCenter: middle,
        startRadius: 0,
        endCenter: middle,
        endRadius: size.width / 2,
        options: [],
      )
    }.cgImage
  }
}
