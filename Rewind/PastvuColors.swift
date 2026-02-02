//
//  PastvuColors.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import UIKit
import VGSL

extension UIColor {
  static func from(year: Int) -> UIColor {
    let t = lerpParameter(
      of: CGFloat(year),
      lowerBound: 1826,
      upperBound: 2000
    )
    let rgbaColor = pastvuGradient.color(at: t)
    return rgbaColor.systemColor
  }
}

typealias Gradient = NonEmptyArray<InterpolationPoint<RGBAColor>>

let pastvuGradient: Gradient = NonEmptyArray([
  (0.00, RGBAColor(red: 0, green: 0, blue: 102 / 255.0, alpha: 1)),
  (0.30, RGBAColor(red: 0, green: 0, blue: 171 / 255.0, alpha: 1)),
  (0.36, RGBAColor(red: 57 / 255.0, green: 0, blue: 171 / 255.0, alpha: 1)),
  (0.42, RGBAColor(red: 114 / 255.0, green: 0, blue: 171 / 255.0, alpha: 1)),
  (0.48, RGBAColor(red: 171 / 255.0, green: 0, blue: 171 / 255.0, alpha: 1)),
  (0.53, RGBAColor(red: 171 / 255.0, green: 0, blue: 114 / 255.0, alpha: 1)),
  (0.59, RGBAColor(red: 171 / 255.0, green: 0, blue: 57 / 255.0, alpha: 1)),
  (0.65, RGBAColor(red: 171 / 255.0, green: 0, blue: 0, alpha: 1)),
  (0.71, RGBAColor(red: 171 / 255.0, green: 57 / 255.0, blue: 0, alpha: 1)),
  (0.76, RGBAColor(red: 171 / 255.0, green: 114 / 255.0, blue: 0, alpha: 1)),
  (0.82, RGBAColor(red: 171 / 255.0, green: 171 / 255.0, blue: 0, alpha: 1)),
  (0.88, RGBAColor(red: 114 / 255.0, green: 171 / 255.0, blue: 0, alpha: 1)),
  (0.94, RGBAColor(red: 57 / 255.0, green: 171 / 255.0, blue: 0, alpha: 1)),
  (1.00, RGBAColor(red: 0, green: 171 / 255.0, blue: 0, alpha: 1)),
].map { InterpolationPoint($0, $1) })!

extension RGBAColor: Interpolatable {
  @inlinable
  func lerp(at: CGFloat, between lhs: RGBAColor, _ rhs: RGBAColor) -> RGBAColor {
    RGBAColor(
      red: Rewind.lerp(at: at, between: lhs.red, rhs.red),
      green: Rewind.lerp(at: at, between: lhs.green, rhs.green),
      blue: Rewind.lerp(at: at, between: lhs.blue, rhs.blue),
      alpha: Rewind.lerp(at: at, between: lhs.alpha, rhs.alpha)
    )
  }
}

extension Gradient {
  fileprivate func color(at t: CGFloat) -> RGBAColor {
    lerp(at: t, in: self)
  }
}
