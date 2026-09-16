//
//  MagicEffect.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

import SwiftUI

struct MagicEffect: ViewModifier, Animatable {
  var origin: CGPoint
  var tuning: MagicTuning
  var time: Double
  var reveal: Double
  var strength: Double

  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(reveal, strength) }
    set {
      reveal = newValue.first
      strength = newValue.second
    }
  }

  func body(content: Content) -> some View {
    content
      .blur(radius: tuning.blur * strength, opaque: true)
      .overlay {
        Rectangle()
          .colorEffect(ShaderLibrary.magicGlow(
            .boundingRect,
            .float(time),
            .float(tuning.blobSize),
            .float(tuning.blobSpread),
            .float(tuning.blobSpeed),
            .float(tuning.hueSpeed),
          ))
          .opacity(tuning.glow)
      }
      .overlay {
        Color(white: tuning.dustGray).mask { dust(sparkle: 0) }
      }
      .overlay {
        sparkleColor.mask { dust(sparkle: 1) }
      }
      .opacity(strength)
      .mask { ripple }
  }

  private func dust(sparkle: Double) -> some View {
    Rectangle()
      .colorEffect(ShaderLibrary.magicDust(
        .boundingRect,
        .float(time),
        .float2(origin),
        .float(reveal),
        .float(tuning.wind),
        .float(tuning.edge),
        .float(tuning.dustAmount),
        .float(tuning.dustGap),
        .float(tuning.dustSize),
        .float(tuning.dustSpeed),
        .float(tuning.dustWander),
        .float(tuning.dustFlow),
        .float(tuning.dustSparkle),
        .float(sparkle),
      ))
  }

  private var sparkleColor: Color {
    if #available(iOS 26, *) {
      Color.white.exposureAdjust(tuning.exposure)
    } else {
      .white
    }
  }

  private var ripple: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let corners = [
        CGPoint.zero,
        CGPoint(x: size.width, y: 0),
        CGPoint(x: 0, y: size.height),
        CGPoint(x: size.width, y: size.height),
      ]
      let farthest = corners.map { hypot($0.x - origin.x, $0.y - origin.y) }.max() ?? 0
      let radius = reveal * (farthest + tuning.edge)
      RadialGradient(
        colors: [.black, .clear],
        center: UnitPoint(x: origin.x / size.width, y: origin.y / size.height),
        startRadius: max(0, radius - tuning.edge),
        endRadius: max(radius, 1),
      )
    }
  }
}
