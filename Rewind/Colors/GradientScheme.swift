//
//  GradientScheme.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 29. 3. 2026..
//

import SwiftUI
import UIKit
import VGSL

enum GradientScheme: Codable, Equatable, CaseIterable {
  typealias Value = NonEmptyArray<InterpolationPoint<RGBAColor>>

  case rewind
  case pastvu
  case warm
  case ocean
  case bw

  var title: LocalizedStringKey {
    switch self {
    case .rewind: "Rewind"
    case .pastvu: "PastVu"
    case .warm: "Warm"
    case .ocean: "Ocean"
    case .bw: "Black & White"
    }
  }
}

extension RGBAColor: Interpolatable {
  @inlinable
  func lerp(at: CGFloat, between lhs: RGBAColor, _ rhs: RGBAColor) -> RGBAColor {
    RGBAColor(
      red: Rewind.lerp(at: at, between: lhs.red, rhs.red),
      green: Rewind.lerp(at: at, between: lhs.green, rhs.green),
      blue: Rewind.lerp(at: at, between: lhs.blue, rhs.blue),
      alpha: Rewind.lerp(at: at, between: lhs.alpha, rhs.alpha),
    )
  }
}

extension GradientScheme {
  func color(at year: Int) -> RGBAColor {
    let t = lerpParameter(
      of: CGFloat(year),
      lowerBound: 1826,
      upperBound: 2000,
    )
    return lerp(at: t, in: value)
  }

  func uiColor(at year: Int) -> UIColor {
    color(at: year).systemColor
  }
}

extension CAGradientLayer {
  func set(_ gradient: GradientScheme) {
    locations = []
    colors = []

    for point in gradient.value {
      let (position, color) = (point.position, point.value)
      locations?.append(NSNumber(value: position))
      colors?.append(color.systemColor.cgColor)
    }
  }
}

extension EnvironmentValues {
  @Entry
  var gradientScheme: GradientScheme = SettingsState.default.gradientScheme
}
