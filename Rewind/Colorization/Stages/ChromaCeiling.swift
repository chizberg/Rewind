//
//  ChromaCeiling.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

import Foundation

// The limit on how saturated a result may get: a frame whose color reaches past the ceiling is
// scaled down as a whole until it fits under it. One factor for the entire frame, and never above
// 1, so no pixel changes hue and nothing gets more color than the model gave it; README's "Chroma
// ceiling" has the rest. The limit apply measures a frame against is internal because the
// reference records the ceiling as a stage of its own, and the parity test pins it on its own.
enum ChromaCeiling {
  // Where the ceiling sits for a model that asks for no gain, in Lab chroma units. It moves with
  // the gain because boldness multiplies the model's color: held at 24, the ceiling would take
  // back most of what a gain of 1.5 had just added. The reference's own cap, 24 * bold.
  private static let chromaAtUnitBoldness: Float = 24

  static func apply(to ab: ABPlanes, boldness: Float) -> ABPlanes {
    let ceiling = limit(boldness: boldness)
    let peak = ab.peakChroma
    guard peak > ceiling else {
      return ab
    }
    return ab.chromaScaled(by: ceiling / peak)
  }

  // The highest chroma a frame from this model may peak at. The gain is the one the model asked
  // for, not the one boldness's guard was left with: the ceiling follows the model's constant, so
  // that withdrawing the gain on a tinted frame lowers its color without also lowering the ceiling
  // it is measured against. The reference raises the ceiling by whichever lever a model turns up,
  // which for ECCV16 is the rebalance exponent inside its graph rather than a gain here; at the
  // values both models ship, that comes to the same 24.
  static func limit(boldness: Float) -> Float {
    chromaAtUnitBoldness * boldness
  }
}
