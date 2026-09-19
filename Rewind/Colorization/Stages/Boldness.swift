//
//  Boldness.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

import Foundation

// A gain on the predicted color, weighted so it lifts only the pixels whose lightness can carry
// color, and withdrawn on a frame the model has painted in one flat tint. How much gain a model
// asks for is its own constant; README's "Boldness" has the rest. The three steps apply is built
// from are internal rather than private because the reference records each as a stage of its own,
// and the parity test pins them one by one.
enum Boldness {
  // The gain is off at or below L=20, full between L=35 and L=75, and off again at or above
  // L=90. Deep shadow and blown highlight cannot hold chroma, so a gain there only pushes pixels
  // out of sRGB. The reference's own bounds, lum_weight(lo=20, hi=90, soft=15).
  private static let lightnessLow: Float = 20
  private static let lightnessHigh: Float = 90
  private static let lightnessSoft: Float = 15

  // Where the guard below starts withdrawing the gain and where it is gone entirely, on the cast
  // ratio. The reference's own pair, apply_boldness(c_lo=0.75, c_hi=0.95).
  private static let castGuardLow: Float = 0.75
  private static let castGuardHigh: Float = 0.95

  // How wide the weight map's blur reaches on a frame of the reference's long side, in pixels.
  private static let radiusAtReference = 24.0
  // This port's own floor, like the bilateral's: it binds at 233 px and below, where the scaled
  // radius rounds to 3 px and the map keeps the lightness texture it exists to erase.
  private static let minimumRadius = 4

  // A frame this close to gray has no color direction to measure, and no gain worth applying.
  private static let negligibleChroma = 1e-6
  // Close enough to 1 that the weight map, the expensive part of the stage, is not worth
  // building. A model that asks for no gain at all leaves through here on every frame.
  private static let negligibleGain: Float = 1e-3

  static func apply(to ab: ABPlanes, lightness: Plane<Float>, boldness: Float) -> ABPlanes {
    assert(ab.size == lightness.size)
    let applied = effectiveBoldness(boldness, castRatio: castRatio(of: ab))
    guard abs(applied - 1) >= negligibleGain else {
      return ab
    }
    let weight = lightnessWeight(lightness)
    var bolder = ab
    for i in 0..<ab.size.pixelCount {
      let gain = 1 + (applied - 1) * weight.values[i]
      bolder.a[i] *= gain
      bolder.b[i] *= gain
    }
    return bolder
  }

  // |mean ab| over mean chroma: how much of the frame's color points one way. At 1 every pixel
  // points the same way, which is a tint laid over the photo rather than a colorization.
  // The sums are Double because a Float one loses the low bits over millions of additions; the
  // reference adds them up in float32.
  static func castRatio(of ab: ABPlanes) -> Float {
    var sumA = 0.0
    var sumB = 0.0
    var sumChroma = 0.0
    for i in 0..<ab.size.pixelCount {
      sumA += Double(ab.a[i])
      sumB += Double(ab.b[i])
      sumChroma += Double(hypot(ab.a[i], ab.b[i]))
    }
    let count = Double(ab.size.pixelCount)
    let meanChroma = sumChroma / count
    guard meanChroma >= negligibleChroma else {
      return 1
    }
    return Float(hypot(sumA / count, sumB / count) / meanChroma)
  }

  // The requested gain, withdrawn as the frame approaches a single tint: on a sepia frame a
  // saturation control is really a sepia-strength control. The guard only ever attenuates, so the
  // color can never end up further from what the model predicted than the model's own gain asks.
  static func effectiveBoldness(_ requested: Float, castRatio: Float) -> Float {
    let rolloff = lerpParameter(
      of: castRatio,
      lowerBound: castGuardLow,
      upperBound: castGuardHigh,
    )
    return 1 + (requested - 1) * (1 - rolloff)
  }

  // 1 in the midtones, tapering to 0 in deep shadow and blown highlight, then blurred wide. The
  // blur is not cosmetic: unblurred, the map is a function of L, so it multiplies the lightness
  // texture straight into the color.
  static func lightnessWeight(_ lightness: Plane<Float>) -> Plane<Float> {
    let window = lightness.map { value in
      lerpParameter(of: value - lightnessLow, lowerBound: 0, upperBound: lightnessSoft)
        * lerpParameter(of: lightnessHigh - value, lowerBound: 0, upperBound: lightnessSoft)
    }
    // The reference rounds halves to even, as Python does, and this rounds them away from zero as
    // the rest of the pipeline does. Below maxSide the two land a pixel apart at long sides 300,
    // 700, 1100, 1500 and 1900, and nowhere else.
    let radius = (radiusAtReference * lightness.size.scaleFromReference).rounded()
    return window.boxBlurred(radius: max(minimumRadius, Int(radius)))
  }
}

extension Plane<Float> {
  // cv2.blur over a (2r+1) square: separable, running sums, BORDER_REFLECT_101. A plain average,
  // unlike the other blur in this pipeline: here an edge is the defect being erased, not the
  // thing to preserve. Running sums because the square reaches 63 px across at the full frame,
  // where a direct convolution would cost more than the model does.
  // https://docs.opencv.org/4.x/d4/d86/group__imgproc__filter.html#ga8c45db9afe636703801b0b2e440fce37
  fileprivate func boxBlurred(radius: Int) -> Plane<Float> {
    let width = size.width
    let height = size.height
    let divisor = Float(2 * radius + 1)
    func mirrored(_ index: Int, _ limit: Int) -> Int {
      ColorizationHelpers.mirroredIndex(index, limit: limit)
    }

    var rows = [Float](repeating: 0, count: size.pixelCount)
    for y in 0..<height {
      let row = y * width
      var sum: Float = 0
      for offset in -radius...radius {
        sum += values[row + mirrored(offset, width)]
      }
      for x in 0..<width {
        rows[row + x] = sum / divisor
        sum += values[row + mirrored(x + radius + 1, width)]
          - values[row + mirrored(x - radius, width)]
      }
    }

    var blurred = [Float](repeating: 0, count: size.pixelCount)
    for x in 0..<width {
      var sum: Float = 0
      for offset in -radius...radius {
        sum += rows[mirrored(offset, height) * width + x]
      }
      for y in 0..<height {
        blurred[y * width + x] = sum / divisor
        sum += rows[mirrored(y + radius + 1, height) * width + x]
          - rows[mirrored(y - radius, height) * width + x]
      }
    }

    return Plane(size: size, values: blurred)
  }
}
