//
//  MagicRippleLayer.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import SwiftUI

final class MagicRippleLayer: CAGradientLayer {
  private static let steps = 30

  private var tuning = MagicTuning.default
  private var unitOrigin = CGPoint.zero
  private var farthest = 0.0

  convenience init(tuning: MagicTuning, size: CGSize, origin: CGPoint) {
    self.init()
    self.tuning = tuning
    frame = CGRect(origin: .zero, size: size)
    unitOrigin = CGPoint(x: origin.x / max(size.width, 1), y: origin.y / max(size.height, 1))
    farthest = bounds.farthestCornerDistance(from: origin)
    type = .radial
    colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
    startPoint = unitOrigin
    endPoint = edgePoint(radius: farthest + tuning.edge)
    locations = bandLocations(radius: farthest + tuning.edge)
  }

  func reveal() {
    let progress = (0...Self.steps)
      .map { UnitCurve.easeInOut.value(at: Double($0) / Double(Self.steps)) }
    let radii = progress.map { $0 * (farthest + tuning.edge) }
    let edge = CAKeyframeAnimation(keyPath: "endPoint")
    edge.values = radii.map { edgePoint(radius: $0) }
    edge.duration = tuning.duration
    add(edge, forKey: "endPoint")
    let band = CAKeyframeAnimation(keyPath: "locations")
    band.values = radii.map { bandLocations(radius: $0) }
    band.duration = tuning.duration
    add(band, forKey: "locations")
  }

  private func edgePoint(radius: Double) -> CGPoint {
    CGPoint(
      x: unitOrigin.x + radius / max(bounds.width, 1),
      y: unitOrigin.y + radius / max(bounds.height, 1),
    )
  }

  private func bandLocations(radius: Double) -> [NSNumber] {
    [NSNumber(value: max(0, radius - tuning.edge) / max(radius, 1)), 1]
  }
}
