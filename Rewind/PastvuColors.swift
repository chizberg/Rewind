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

typealias Gradient = [(position: CGFloat, color: RGBAColor)]

private let pastvuGradient: Gradient = [
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
]

extension RGBAColor {
  @inlinable
  func lerp(at: CGFloat, beetween lhs: RGBAColor, _ rhs: RGBAColor) -> RGBAColor {
    RGBAColor(
      red: VGSL.lerp(at: at, beetween: lhs.red, rhs.red),
      green: VGSL.lerp(at: at, beetween: lhs.green, rhs.green),
      blue: VGSL.lerp(at: at, beetween: lhs.blue, rhs.blue),
      alpha: VGSL.lerp(at: at, beetween: lhs.alpha, rhs.alpha)
    )
  }
}

extension Gradient {
  fileprivate func color(at rawT: CGFloat) -> RGBAColor {
    let t = rawT.clamped(in: 0...1)
    guard let index = binSearch(firstEqualOrGreaterThan: t, keyPath: \.position, in: self) else {
      return self.last!.color
    }
    if index == 0 {
      return self.first!.color
    }
    let lowerStop = self[index - 1]
    let upperStop = self[index]
    let t1 = lerpParameter(
      of: t,
      lowerBound: lowerStop.position,
      upperBound: upperStop.position
    )
    return lowerStop.color.lerp(at: t1, beetween: lowerStop.color, upperStop.color)
  }
}

private func lerpParameter<T: FloatingPoint>(of value: T, lowerBound: T, upperBound: T) -> T {
  guard value > lowerBound else { return 0 }
  guard value < upperBound else { return 1 }
  return (value - lowerBound) / (upperBound - lowerBound)
}

private func binSearch<T: Numeric & Comparable>(
  firstEqualOrGreaterThan goal: T,
  in arr: [T]
) -> Int? {
  guard arr.count > 0 else { return nil }
  var lhs = 0
  var rhs = arr.count - 1
  while arr[lhs + 1] < arr[rhs] {
    let mid = (lhs + rhs) / 2
    if arr[mid] >= goal {
      rhs = mid
    } else {
      lhs = mid
    }
  }
  if arr[lhs] >= goal { return lhs }
  if arr[rhs] >= goal { return rhs }
  return nil
}

private func binSearch<T, U: Numeric & Comparable>(
  firstEqualOrGreaterThan goal: U,
  keyPath kp: KeyPath<T, U>,
  in arr: [T]
) -> Int? {
  guard arr.count > 0 else { return nil }
  var lhs = 0
  var rhs = arr.count - 1
  while arr[lhs + 1][keyPath: kp] < arr[rhs][keyPath: kp] {
    let mid = (lhs + rhs) / 2
    if arr[mid][keyPath: kp] >= goal {
      rhs = mid
    } else {
      lhs = mid
    }
  }
  if arr[lhs][keyPath: kp] >= goal { return lhs }
  if arr[rhs][keyPath: kp] >= goal { return rhs }
  return nil
}
