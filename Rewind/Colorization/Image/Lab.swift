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

  static func neutralGray(lightness: Plane<Float>) -> Plane<UInt8> {
    lightness.map { UInt8(sRGB: neutralGray(lightness: $0)) }
  }
}

// sRGB -> CIE L*a*b*, the standard formulas with the constants as OpenCV spells them, because
// every reference number the pipeline is checked against was produced by cv2.cvtColor:
// https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html (RGB <-> CIE L*a*b*)
extension Lab {
  // CIE Lab replaces the cube root below (6/29)³ with a straight line that meets it
  // in value and slope: (1/3)(29/6)² t + 4/29.
  private static let epsilon: Float = 0.008856
  private static let slope: Float = 7.787
  private static let offset: Float = 16.0 / 116.0

  // Y of CIE XYZ: the pixel's light weighted by the eye's sensitivity. The weights are the
  // Y row of the sRGB -> XYZ matrix for D65; green dominates because the eye sees it best.
  private static func luminance(r: Float, g: Float, b: Float) -> Float {
    0.212671 * gammaDecode(r) + 0.715160 * gammaDecode(g) + 0.072169 * gammaDecode(b)
  }

  // L* = 116 f(Y/Yn) - 16, scaled so black is 0 and white is 100. OpenCV's Yn is 1.
  private static func lightness(r: Float, g: Float, b: Float) -> Float {
    116 * f(luminance(r: r, g: g, b: b)) - 16
  }

  // The f of the CIE Lab definition: a cube root, the eye's response to light, with a
  // straight segment near zero where the root's slope would be infinite.
  private static func f(_ t: Float) -> Float {
    t > epsilon ? cbrtf(t) : slope * t + offset
  }

  // The sRGB value of a neutral pixel of this lightness: with a = b = 0 the three channels of
  // Lab -> RGB come out equal, so the whole inverse conversion collapses into one channel.
  private static func neutralGray(lightness: Float) -> Float {
    gammaEncode(fInverse((lightness + 16) / 116))
  }

  // f undone, the Lab -> XYZ direction of the same CIE definition: the cube root becomes a
  // cube, the straight segment is solved for t. Needed to get from L back to Y.
  private static func fInverse(_ u: Float) -> Float {
    let cubed = u * u * u
    return cubed > epsilon ? cubed : (u - offset) / slope
  }

  // sRGB stores channels gamma-encoded, 0.5 is not half the light. This is the inverse of the
  // sRGB transfer function (IEC 61966-2-1): linear near zero, a 2.4 power above 0.04045.
  private static func gammaDecode(_ c: Float) -> Float {
    c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
  }

  // The sRGB transfer function itself (IEC 61966-2-1): linear light back to the encoded value
  // a byte stores. 0.0031308 is where 0.04045 lands after decoding, so the two branches meet.
  private static func gammaEncode(_ c: Float) -> Float {
    c <= 0.0031308 ? 12.92 * c : 1.055 * powf(c, 1 / 2.4) - 0.055
  }
}

extension UInt8 {
  // Half to even is what OpenCV's saturate_cast and numpy's round do; half away from zero
  // would drift against every recorded reference number.
  fileprivate init(sRGB value: Float) {
    self.init((Swift.min(Swift.max(value, 0), 1) * 255).rounded(.toNearestOrEven))
  }
}
