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
// ceiling" has the rest. The two pieces apply is built from are internal because the reference
// records the ceiling as a stage of its own, and the parity test pins them one by one.
enum ChromaCeiling {
  // Where the ceiling sits for a model that asks for no gain, in Lab chroma units. It moves with
  // the gain because boldness multiplies the model's color: held at 24, the ceiling would take
  // back most of what a gain of 1.5 had just added. The reference's own cap, 24 * bold.
  private static let chromaAtUnitBoldness: Float = 24

  // The frame is measured at its 99th percentile of chroma rather than at its maximum. The
  // maximum is one pixel, and on the parity frames it runs to three and a half times the
  // percentile: fitting a frame under the ceiling by a pixel would drain the color out of the rest.
  private static let peakPercentile = 99.0

  // How finely the frame's chroma is binned to find that percentile. What a model predicts is not
  // bounded by anything, but it tops out around 160 on the reference's frames, which puts a bin at
  // a hundredth or two of a chroma unit: far under what the ceiling is worth arguing about.
  private static let histogramBins = 8192

  static func apply(to ab: ABPlanes, boldness: Float) -> ABPlanes {
    let ceiling = limit(boldness: boldness)
    let peak = peakChroma(of: ab)
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

  // How much color the frame has where it is all but at its most colorful.
  static func peakChroma(of ab: ABPlanes) -> Float {
    ab.chroma.percentile(peakPercentile, bins: histogramBins)
  }
}

extension Plane<Float> {
  // numpy.percentile's default linear interpolation, read off a histogram instead of a sorted
  // copy: the rank the percentile asks for falls between two of the sorted values, and the answer
  // is the point between them. Sorting three million floats to read one of them costs about forty
  // times what binning them does (380 ms against 9 at -O). On a frame of that many pixels the two
  // sorted values the rank falls between land in the same bin, and the answer then comes out
  // within a bin's width of the exact one; on a handful of far apart values it would not. Values
  // that are not finite are left out, both because the bin index of one cannot be computed at all
  // and because a single stray pixel must not decide the whole frame's color.
  // https://numpy.org/doc/stable/reference/generated/numpy.percentile.html
  fileprivate func percentile(_ percent: Double, bins binCount: Int) -> Float {
    var minimum = Float.greatestFiniteMagnitude
    var maximum = -Float.greatestFiniteMagnitude
    var count = 0
    for value in values where value.isFinite {
      minimum = min(minimum, value)
      maximum = max(maximum, value)
      count += 1
    }
    guard count > 0 else {
      return 0
    }
    guard maximum > minimum else {
      return minimum
    }

    let width = (maximum - minimum) / Float(binCount)
    var bins = [Int](repeating: 0, count: binCount)
    for value in values where value.isFinite {
      bins[min(binCount - 1, Int((value - minimum) / width))] += 1
    }

    // The rank sits at p/100 of the way from the first sorted value to the last, and inside the
    // bin that holds it the values are taken to be evenly spread.
    let target = percent / 100 * Double(count - 1)
    var below = 0
    for (index, bin) in bins.enumerated() {
      guard Double(below + bin) > target else {
        below += bin
        continue
      }
      let position = Float((target - Double(below)) / Double(bin))
      return minimum + (Float(index) + position) * width
    }
    return maximum
  }
}
