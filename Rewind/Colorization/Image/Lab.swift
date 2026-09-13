//
//  Lab.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Foundation
import VGSL

enum Lab {
  static func lightness(of rgb: RGBPlanes) -> Plane<Float> {
    Plane(size: rgb.size, values: (0..<rgb.size.pixelCount).map { i in
      lightness(r: rgb.r[i], g: rgb.g[i], b: rgb.b[i])
    })
  }

  // L of a gray frame, the input ECCV16 takes instead of an image. The reference converts the
  // squashed gray bytes with skimage's rgb2lab, which agrees with OpenCV's L for R = G = B.
  // https://scikit-image.org/docs/stable/api/skimage.color.html#skimage.color.rgb2lab
  static func lightness(ofGray gray: Plane<UInt8>) -> Plane<Float> {
    gray.map { byte in
      let value = Float(byte) / 255
      return lightness(r: value, g: value, b: value)
    }
  }

  static func neutralGray(lightness: Plane<Float>) -> Plane<UInt8> {
    lightness.map { ColorizationHelpers.byte(sRGB: neutralGray(lightness: $0)) }
  }

  // The colorized photo: every pixel's L from the photo and ab from the model, through XYZ back to
  // sRGB with OpenCV's matrix. Like cv2's float COLOR_Lab2RGB, the linear channels are clamped to
  // 0...1 before the transfer function, so a color outside sRGB loses the excess.
  // https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html#color_convert_rgb_xyz
  static func rgb(lightness: Plane<Float>, ab: ABPlanes) -> RGBPlanes {
    assert(lightness.size == ab.size)
    let count = lightness.size.pixelCount
    var r = [Float](repeating: 0, count: count)
    var g = [Float](repeating: 0, count: count)
    var b = [Float](repeating: 0, count: count)
    for i in 0..<count {
      let fy = fOfLuminance(lightness: lightness.values[i])
      let x = whiteX * fInverse(fy + ab.a[i] / 500)
      let y = fInverse(fy)
      let z = whiteZ * fInverse(fy - ab.b[i] / 200)
      r[i] = gammaEncode((3.240479 * x - 1.53715 * y - 0.498535 * z).clamp(0...1))
      g[i] = gammaEncode((-0.969256 * x + 1.875991 * y + 0.041556 * z).clamp(0...1))
      b[i] = gammaEncode((0.055648 * x - 0.204043 * y + 1.057311 * z).clamp(0...1))
    }
    return RGBPlanes(size: lightness.size, r: r, g: g, b: b)
  }
}

// sRGB -> CIE L*a*b*, the standard formulas with the constants as OpenCV spells them, because
// every reference number the pipeline is checked against was produced by cv2.cvtColor:
// https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html (RGB <-> CIE L*a*b*)
extension Lab {
  // CIE Lab replaces the cube root below (6/29)³ with a straight line that meets it
  // in value and slope: (1/3)(29/6)² t + 4/29.
  private static let threshold: Float = 0.008856
  private static let slope: Float = 7.787
  private static let offset: Float = 16.0 / 116.0
  // OpenCV's D65 white, Xn and Zn: Lab holds X and Z relative to white, the way back multiplies
  // them in. Yn is 1, so Y has no factor.
  private static let whiteX: Float = 0.950456
  private static let whiteZ: Float = 1.088754

  // Y of CIE XYZ: the pixel's light weighted by the eye's sensitivity. The weights are the
  // Y row of the sRGB -> XYZ matrix for D65; green dominates because the eye sees it best.
  private static func luminance(r: Float, g: Float, b: Float) -> Float {
    0.212671 * gammaDecode(r) + 0.715160 * gammaDecode(g) + 0.072169 * gammaDecode(b)
  }

  // L* = 116 f(Y/Yn) - 16, scaled so black is 0 and white is 100. OpenCV's Yn is 1.
  private static func lightness(r: Float, g: Float, b: Float) -> Float {
    116 * f(luminance(r: r, g: g, b: b)) - 16
  }

  // L* = 116 f(Y/Yn) - 16 solved for f(Y/Yn): the first step from L back to XYZ.
  private static func fOfLuminance(lightness: Float) -> Float {
    (lightness + 16) / 116
  }

  // The f of the CIE Lab definition: a cube root, the eye's response to light, with a
  // straight segment near zero where the root's slope would be infinite.
  private static func f(_ t: Float) -> Float {
    t > threshold ? cbrtf(t) : slope * t + offset
  }

  // The sRGB value of a neutral pixel of this lightness: with a = b = 0 the three channels of
  // Lab -> RGB come out equal, so the whole inverse conversion collapses into one channel.
  private static func neutralGray(lightness: Float) -> Float {
    gammaEncode(fInverse(fOfLuminance(lightness: lightness)))
  }

  // f undone, the Lab -> XYZ direction of the same CIE definition: the cube root becomes a
  // cube, the straight segment is solved for t. Needed to get from L back to Y.
  private static func fInverse(_ u: Float) -> Float {
    let cubed = u * u * u
    return cubed > threshold ? cubed : (u - offset) / slope
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

// The 8-bit Lab that CLAHE runs in. cv2.COLOR_RGB2LAB on bytes scales L to 0...255 in fixed-point
// arithmetic with its own rounding, one off the float formulas above on 40 of the 256 gray
// levels, and CLAHE's histograms notice. Both tables are cv2.cvtColor's own output: the gray ramp
// forward, and L back with a = b = 128. The way back is the R channel alone: the three channels
// come out one apart on 16 levels, and the reference, which keeps all three, sits 0.006 higher
// in the mean of 3_clahe_rgb than this one-channel frame.
extension Lab {
  static let grayToLightnessByte: [UInt8] = [
    0, 1, 1, 2, 2, 3, 5, 5, 6, 7, 7, 8, 9, 9, 10, 11,
    12, 12, 14, 15, 16, 17, 18, 19, 21, 23, 24, 25, 27, 27, 28, 30,
    31, 33, 34, 35, 36, 38, 39, 40, 41, 42, 43, 45, 46, 47, 48, 50,
    51, 52, 53, 54, 55, 57, 58, 59, 60, 61, 62, 63, 65, 66, 67, 68,
    69, 70, 71, 73, 74, 75, 76, 77, 78, 79, 80, 82, 82, 83, 85, 86,
    87, 88, 89, 90, 91, 92, 93, 94, 95, 97, 98, 99, 100, 101, 102, 103,
    104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 119, 119,
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136,
    137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152,
    153, 154, 155, 156, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167,
    168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 180, 181, 182,
    183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 196, 197,
    198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 208, 209, 210, 211, 212,
    213, 214, 215, 216, 217, 218, 219, 219, 220, 221, 222, 223, 224, 225, 226, 227,
    228, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 237, 238, 239, 240, 241,
    242, 243, 244, 245, 245, 246, 247, 248, 249, 250, 251, 252, 253, 253, 254, 255,
  ]

  static let lightnessByteToGray: [UInt8] = [
    0, 2, 3, 4, 6, 6, 8, 10, 11, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 23, 24, 25, 25, 26, 27, 28, 29, 30, 30, 31, 32,
    33, 34, 34, 35, 36, 36, 37, 38, 39, 40, 41, 42, 42, 43, 44, 45,
    46, 47, 47, 48, 49, 50, 51, 52, 53, 53, 54, 55, 56, 57, 58, 58,
    59, 60, 61, 62, 63, 64, 65, 66, 67, 67, 68, 69, 70, 71, 72, 73,
    74, 75, 75, 77, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88,
    89, 90, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103,
    104, 105, 106, 107, 108, 109, 110, 111, 112, 112, 113, 115, 115, 116, 117, 118,
    119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134,
    135, 136, 137, 138, 139, 140, 141, 143, 144, 145, 146, 147, 148, 149, 150, 151,
    152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167,
    168, 169, 170, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184,
    185, 186, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 202,
    203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 214, 215, 216, 217, 218, 219,
    220, 221, 222, 224, 225, 226, 227, 228, 229, 230, 231, 232, 234, 235, 236, 237,
    238, 239, 240, 241, 243, 244, 245, 246, 247, 248, 249, 250, 252, 253, 254, 255,
  ]
}
