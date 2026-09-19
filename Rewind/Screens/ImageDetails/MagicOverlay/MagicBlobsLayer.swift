//
//  MagicBlobsLayer.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import UIKit

final class MagicBlobsLayer: CALayer {
  private static let count = 5
  private static let pathHorizon = 120.0
  private static let pathSamplesPerSecond = 4.0
  private static let hueSteps = 24
  private static let sideToRadius = 4.0
  private static let falloff: [(location: Double, alpha: Double)] = [
    (0, 1), (0.25, 0.78), (0.5, 0.37), (0.75, 0.1), (1, 0),
  ]

  private var tuning = MagicTuning.default
  private var size = CGSize.zero

  convenience init(tuning: MagicTuning, size: CGSize) {
    self.init()
    self.tuning = tuning
    self.size = size
    opacity = Float(tuning.glow)
    let side = min(size.width, size.height) * tuning.blobSize * Self.sideToRadius
    for index in 0..<Self.count {
      let blob = CAGradientLayer()
      blob.type = .radial
      blob.startPoint = CGPoint(x: 0.5, y: 0.5)
      blob.endPoint = CGPoint(x: 1, y: 1)
      blob.locations = Self.falloff.map { NSNumber(value: $0.location) }
      blob.bounds = CGRect(x: 0, y: 0, width: side, height: side)
      blob.position = center(of: index, at: 0)
      blob.colors = colors(of: index, at: 0)
      addSublayer(blob)
      wander(blob, index: index)
      cycleHue(blob, index: index)
    }
  }

  private func wander(_ blob: CALayer, index: Int) {
    guard tuning.blobSpeed > 0 else { return }
    let animation = CAKeyframeAnimation(keyPath: "position")
    let samples = Int(Self.pathHorizon * Self.pathSamplesPerSecond)
    animation.values = (0...samples).map {
      center(of: index, at: Double($0) / Self.pathSamplesPerSecond)
    }
    animation.calculationMode = .cubic
    animation.duration = Self.pathHorizon
    animation.autoreverses = true
    animation.repeatCount = .infinity
    blob.add(animation, forKey: "wander")
  }

  private func cycleHue(_ blob: CALayer, index: Int) {
    guard tuning.hueSpeed > 0 else { return }
    let period = 1 / tuning.hueSpeed
    let animation = CAKeyframeAnimation(keyPath: "colors")
    animation.values = (0...Self.hueSteps).map {
      colors(of: index, at: Double($0) / Double(Self.hueSteps) * period)
    }
    animation.duration = period
    animation.repeatCount = .infinity
    blob.add(animation, forKey: "hue")
  }

  private func center(of index: Int, at time: Double) -> CGPoint {
    let drift = time * tuning.blobSpeed
    let position = Double(index)
    let path = CGPoint(
      x: sin(drift * (0.7 + 0.13 * position) + position * 1.7),
      y: cos(drift * (0.5 + 0.11 * position) + position * 2.3),
    )
    return CGPoint(
      x: size.width * (0.5 + tuning.blobSpread * path.x),
      y: size.height * (0.5 + tuning.blobSpread * path.y),
    )
  }

  private func colors(of index: Int, at time: Double) -> [CGColor] {
    let hue = (Double(index) / Double(Self.count) + time * tuning.hueSpeed)
      .truncatingRemainder(dividingBy: 1)
    let phases = [0, 1.0 / 3, 2.0 / 3]
    let rgb = phases.map { 0.5 + 0.5 * cos(2 * .pi * (hue + $0)) }
    return Self.falloff
      .map { UIColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: $0.alpha).cgColor }
  }
}
