//
//  MagicDustLayer.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import UIKit
import VGSL

final class MagicDustLayer: CAEmitterLayer {
  private static let flowHorizon = 300.0
  private static let flowSamplesPerSecond = 4.0
  private static let lifeVariation = 0.5
  private static let sizeVariation = 0.3

  private var tuning = MagicTuning.default
  private var pulseCenter = CGPoint.zero
  private var farthest = 0.0

  convenience init(tuning: MagicTuning, size: CGSize, origin: CGPoint, scale: CGFloat) {
    self.init()
    self.tuning = tuning
    let flow = Self.flowPath(tuning: tuning, size: size, origin: origin)
    let margin = flow.reduce(0) { max($0, abs($1.x), abs($1.y)) }
    let area = CGRect(origin: .zero, size: size).insetBy(dx: -margin, dy: -margin)
    frame = area
    pulseCenter = CGPoint(x: origin.x + margin, y: origin.y + margin)
    farthest = CGRect(origin: .zero, size: size).farthestCornerDistance(from: origin)
    emitterShape = .rectangle
    emitterMode = .volume
    emitterPosition = CGPoint(x: area.width / 2, y: area.height / 2)
    emitterSize = area.size
    renderMode = .unordered
    wantsExtendedDynamicRangeContent = true
    let count = tuning.dustAmount * area.width * area.height / (tuning.dustGap * tuning.dustGap)
    let dust = cell(brightness: 1, count: count, life: tuning.dustLife, scale: scale)
    dust.color = UIColor(white: tuning.dustGray, alpha: 1).cgColor
    dust.lifetimeRange = Float(tuning.dustLife * Self.lifeVariation)
    let sparkle = cell(
      brightness: pow(2, tuning.exposure),
      count: count * tuning.sparkleShare,
      life: tuning.sparkleLife,
      scale: scale,
    )
    sparkle.alphaSpeed = Float(-1 / tuning.sparkleLife)
    emitterCells = [dust, sparkle]
    beginTime = CACurrentMediaTime() - tuning.dustLife * (1 + Self.lifeVariation)
    drift(along: flow)
  }

  func gust() {
    guard farthest > 0 else { return }
    let shift = CGPoint(x: pulseCenter.x - bounds.midX, y: pulseCenter.y - bounds.midY)
    let scale = 1 + tuning.wind / farthest
    let pulse = CATransform3DConcat(
      CATransform3DConcat(
        CATransform3DMakeTranslation(-shift.x, -shift.y, 0),
        CATransform3DMakeScale(scale, scale, 1),
      ),
      CATransform3DMakeTranslation(shift.x, shift.y, 0),
    )
    let animation = CABasicAnimation(keyPath: "transform")
    animation.fromValue = CATransform3DIdentity
    animation.toValue = pulse
    animation.duration = tuning.duration
    animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
    CATransaction.performWithoutAnimations {
      transform = pulse
    }
    add(animation, forKey: "gust")
  }

  private func cell(
    brightness: Double,
    count: Double,
    life: Double,
    scale: CGFloat
  ) -> CAEmitterCell {
    let cell = CAEmitterCell()
    cell.contents = MagicDot(brightness: brightness).rendered()
    cell.contentsScale = scale
    cell.scale = tuning.dustSize / MagicDot.diameter
    cell.scaleRange = cell.scale * Self.sizeVariation
    cell.birthRate = Float(count / life)
    cell.lifetime = Float(life)
    cell.velocity = tuning.dustWander * tuning.dustSpeed
    cell.velocityRange = cell.velocity
    cell.emissionRange = 2 * .pi
    return cell
  }

  private func drift(along flow: [CGPoint]) {
    guard flow.count > 1 else { return }
    let animation = CAKeyframeAnimation(keyPath: "position")
    animation.values = flow.map { CGPoint(x: position.x + $0.x, y: position.y + $0.y) }
    animation.calculationMode = .cubic
    animation.duration = Self.flowHorizon
    animation.autoreverses = true
    animation.repeatCount = .infinity
    animation.beginTime = convertTime(CACurrentMediaTime(), from: nil)
    add(animation, forKey: "flow")
  }

  private static func flowPath(tuning: MagicTuning, size: CGSize, origin: CGPoint) -> [CGPoint] {
    guard tuning.dustSpeed > 0 else { return [] }
    let toCorner = CGPoint(x: -origin.x, y: size.height - origin.y)
    let length = max(hypot(toCorner.x, toCorner.y), 1)
    let along = CGPoint(x: toCorner.x / length, y: toCorner.y / length)
    let across = CGPoint(x: -along.y, y: along.x)
    let samples = Int(flowHorizon * flowSamplesPerSecond)
    let points = (0...samples).map { sample in
      let breeze = Double(sample) / flowSamplesPerSecond * tuning.dustSpeed
      let meander = CGPoint(
        x: (sin(0.17 * breeze) + 0.5 * sin(0.41 * breeze)) / 1.5,
        y: (cos(0.13 * breeze) + 0.5 * cos(0.37 * breeze)) / 1.5,
      )
      return CGPoint(
        x: tuning.dustFlow * (meander.x * along.x + meander.y * across.x),
        y: tuning.dustFlow * (meander.x * along.y + meander.y * across.y),
      )
    }
    let start = points[0]
    return points.map { CGPoint(x: $0.x - start.x, y: $0.y - start.y) }
  }
}
