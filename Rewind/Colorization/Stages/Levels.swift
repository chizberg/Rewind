//
//  Levels.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

import Foundation

// The photo's lightness spread back over the whole scale: the band between its first and its
// ninety-ninth percentile is stretched onto 0...100. Everything downstream reads this plane, and on
// a scan that lives in a slice of the scale each of them is better for having the whole of it: the
// model, which returns a flat sepia tint rather than a colorization when the frame it is handed is
// dark and flat, the two post-process stages that weigh color by lightness, and the composed
// result, which gets the contrast of a photograph. This is the one stage that changes the photo's
// own brightness rather than only steering color; README's "Levels" has what that costs and how
// little it does to a photo that already fills the scale. The reference's stretch_levels.
enum Levels {
  // The band that fills the scale. Taken at percentiles rather than at the darkest and the
  // brightest pixel because one speck of dust at either end would otherwise set the range for the
  // whole frame and leave the stretch with nothing to do. The price is that the outer percent at
  // each end is crushed flat onto the end of the scale. The reference's own bounds.
  private static let lowPercentile = 1.0
  private static let highPercentile = 99.0

  // How finely the lightness is binned to find those two. The bins span the range the frame
  // actually covers, so on a faded scan they are finer still, and at the widest — the whole of L —
  // one is 0.0122 of a unit. A step of an 8-bit gray is worth between 0.27 and 0.51 of a unit, so
  // on a photograph the ends of the band land far closer to the exact percentiles than the frame
  // itself can tell apart.
  private static let histogramBins = 8192

  // The top of the L* scale, which is what the band is stretched onto.
  private static let lightnessTop: Float = 100

  static func stretch(lightness: Plane<Float>) -> Plane<Float> {
    let low = lightness.percentile(lowPercentile, bins: histogramBins)
    let high = lightness.percentile(highPercentile, bins: histogramBins)
    // A frame of a single tone has no band to stretch, and dividing by its width would send every
    // pixel of it to black.
    guard high > low else {
      return lightness
    }
    return lightness.map { lightnessTop * lerpParameter(of: $0, lowerBound: low, upperBound: high) }
  }
}
