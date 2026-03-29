//
//  GradientSchemeValue.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 05.02.2025.
//

import UIKit
import VGSL

extension GradientScheme {
  var value: Value {
    switch self {
    case .rewind: .rewind
    case .pastvu: .pastvu
    case .warm: .warm
    case .ocean: .ocean
    case .bw: .bw
    }
  }

  // color that is used for foreground if the background is too light
  var darkForeground: RGBAColor? {
    switch self {
    case .rewind, .pastvu, .bw: nil
    case .warm: GradientScheme.Value.warm.first?.value
    case .ocean: GradientScheme.Value.ocean.first?.value
    }
  }
}

extension GradientScheme.Value {
  fileprivate init(_ points: [(CGFloat, RGBAColor)]) {
    self = NonEmptyArray(points)!.map { InterpolationPoint($0, $1) }
  }

  fileprivate static let rewind = GradientScheme.Value([
    (0.00, RGBAColor(.systemIndigo)),
    (0.30, RGBAColor(.systemBlue)),
    (0.42, RGBAColor(.systemPurple)),
    (0.48, RGBAColor(.systemPink)),
    (0.65, RGBAColor(.systemRed)),
    (0.76, RGBAColor(.systemOrange)),
    (0.82, RGBAColor(.systemYellow)),
    (1.00, RGBAColor(.systemGreen)),
  ])

  fileprivate static let pastvu = GradientScheme.Value([
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
  ])

  fileprivate static let warm = GradientScheme.Value([
    (0.00, RGBAColor(red: 0.40, green: 0.05, blue: 0.10, alpha: 1)),
    (0.25, RGBAColor(red: 0.60, green: 0.15, blue: 0.15, alpha: 1)),
    (0.50, RGBAColor(red: 0.80, green: 0.30, blue: 0.20, alpha: 1)),
    (0.75, RGBAColor(red: 0.93, green: 0.60, blue: 0.45, alpha: 1)),
    (1.00, RGBAColor(red: 1.0, green: 0.87, blue: 0.78, alpha: 1)),
  ])

  fileprivate static let ocean = GradientScheme.Value([
    (0.00, RGBAColor(red: 0.05, green: 0.15, blue: 0.35, alpha: 1)),
    (0.25, RGBAColor(red: 0.12, green: 0.35, blue: 0.60, alpha: 1)),
    (0.50, RGBAColor(red: 0.25, green: 0.52, blue: 0.78, alpha: 1)),
    (0.75, RGBAColor(red: 0.45, green: 0.70, blue: 0.88, alpha: 1)),
    (1.00, RGBAColor(red: 0.68, green: 0.85, blue: 0.95, alpha: 1)),
  ])

  fileprivate static let bw = GradientScheme.Value([
    (0.00, .black),
    (1.00, .white),
  ])
}
