//
//  Lab.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Foundation

enum Lab {
  static func lightness(of rgb: RGBPlanes) -> Plane<Float> {
    Plane(size: rgb.size, values: (0..<rgb.size.pixelCount).map { i in
      lightness(r: rgb.r[i], g: rgb.g[i], b: rgb.b[i])
    })
  }
}

// sRGB -> CIE L*a*b*, the standard formulas with the constants as OpenCV spells them, because
// every reference number the pipeline is checked against was produced by cv2.cvtColor:
// https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html (RGB <-> CIE L*a*b*)
extension Lab {
  // CIE Lab replaces the cube root below (6/29)³ with a straight line that meets it
  // in value and slope: (1/3)(29/6)² t + 4/29.
  private static let labEpsilon: Float = 0.008856
  private static let labSlope: Float = 7.787
  private static let labOffset: Float = 16.0 / 116.0

  // Y of CIE XYZ: the pixel's light weighted by the eye's sensitivity. The weights are the
  // Y row of the sRGB -> XYZ matrix for D65; green dominates because the eye sees it best.
  private static func luminance(r: Float, g: Float, b: Float) -> Float {
    0.212671 * gammaDecode(r) + 0.715160 * gammaDecode(g) + 0.072169 * gammaDecode(b)
  }

  // L* = 116 f(Y/Yn) - 16, scaled so black is 0 and white is 100. OpenCV's Yn is 1.
  private static func lightness(r: Float, g: Float, b: Float) -> Float {
    116 * labF(luminance(r: r, g: g, b: b)) - 16
  }

  // The f of the CIE Lab definition: a cube root, the eye's response to light, with a
  // straight segment near zero where the root's slope would be infinite.
  private static func labF(_ t: Float) -> Float {
    t > labEpsilon ? cbrtf(t) : labSlope * t + labOffset
  }

  // sRGB stores channels gamma-encoded, 0.5 is not half the light. This is the inverse of the
  // sRGB transfer function (IEC 61966-2-1): linear near zero, a 2.4 power above 0.04045.
  private static func gammaDecode(_ c: Float) -> Float {
    c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
  }
}
