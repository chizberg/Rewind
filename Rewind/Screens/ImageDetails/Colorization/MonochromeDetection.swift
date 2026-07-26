//
//  MonochromeDetection.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 7. 2026..
//

import Accelerate
import simd
import SwiftUI
import VGSL

func isMonochrome(image: UIImage) async throws -> Bool {
  try await Task.detached(priority: .userInitiated) {
    guard let cgImage = image.cgImage else {
      assertionFailure()
      return false
    }
    if cgImage.colorSpace?.model == .monochrome {
      return true
    }
    let context = try makeContext(image: cgImage)
    let pixels = try makePixels(context: context)
    let deviation = try deviationFromMonochrome(pixels: pixels)
    return deviation < monochromeThreshold
  }.value
}

private func makeContext(image: CGImage) throws -> CGContext {
  let (srcW, srcH) = (image.width, image.height)

  let scale = Double(maxDownsampledDimension) / Double(max(srcW, srcH))
  let w = max(1, Int((Double(srcW) * scale).rounded()))
  let h = max(1, Int((Double(srcH) * scale).rounded()))

  guard let ctx = CGContext(
    data: nil,
    width: w,
    height: h,
    bitsPerComponent: 8,
    bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else {
    throw HandlingError("Unable to create CGContext")
  }

  ctx.interpolationQuality = .low
  ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

  return ctx
}

// colors are plain for vDSP computations
private struct Pixels {
  var r: [Float]
  var g: [Float]
  var b: [Float]

  var count: Int {
    assert(r.count == g.count && g.count == b.count)
    return r.count
  }
}

private func makePixels(context: CGContext) throws -> Pixels {
  guard let data = context.data else {
    throw HandlingError("CGContext has no data")
  }
  guard context.bytesPerRow == context.width * 4 else {
    throw HandlingError("Unexpected row padding: \(context.bytesPerRow)")
  }

  let count = context.width * context.height
  let bytes = data.assumingMemoryBound(to: UInt8.self)

  // bytes are laid out as R G B A R G B A ..., so a channel
  // is every 4th byte starting at its own offset.
  // the format is set in makeContext(image:)
  func channel(offset: Int) -> [Float] {
    var values = [Float](repeating: 0, count: count)
    vDSP_vfltu8(bytes + offset, 4, &values, 1, UInt(count)) // UInt8 -> Float
    return vDSP.multiply(1 / 255, values)
  }

  return Pixels(
    r: channel(offset: 0),
    g: channel(offset: 1),
    b: channel(offset: 2)
  )
}

// monochrome image pixels lie on a line in the RGB space
// color image pixels are more like a cloud, so they deviate from a line
// ~0 for monochrome, a regular color image is ~0.1, max is ~2/3
private func deviationFromMonochrome(pixels: Pixels) throws -> Float {
  guard pixels.count > 2 else {
    throw HandlingError("Too few points to compute deviation")
  }

  // each channel is shifted by its own average, so that the cloud of pixels
  // sits around zero. otherwise the line would be forced to pass through
  // black, and the line of a sepia image does not
  let r = vDSP.add(-vDSP.mean(pixels.r), pixels.r)
  let g = vDSP.add(-vDSP.mean(pixels.g), pixels.g)
  let b = vDSP.add(-vDSP.mean(pixels.b), pixels.b)

  // covariance: rr, gg and bb are how much each channel varies on its own,
  // the rest is how much a pair of channels varies together
  let inverseCount = 1 / Float(pixels.count)
  let rr = vDSP.dot(r, r) * inverseCount
  let gg = vDSP.dot(g, g) * inverseCount
  let bb = vDSP.dot(b, b) * inverseCount
  let rg = vDSP.dot(r, g) * inverseCount
  let rb = vDSP.dot(r, b) * inverseCount
  let gb = vDSP.dot(g, b) * inverseCount

  let total = rr + gg + bb
  guard total.isApproximatelyGreaterThan(0) else {
    // if the sum of squares is 0, then the image is a single flat color
    // the matrix will be empty and the computations will return NaNs
    throw HandlingError("The image is a single flat color. Can't be handled")
  }

  let covariance = simd_float3x3(columns: (
    SIMD3(rr, rg, rb),
    SIMD3(rg, gg, gb),
    SIMD3(rb, gb, bb)
  ))

  // power iteration: multiplying a vector by the matrix stretches it the most
  // along the direction of the largest spread, so repeating turns the vector
  // towards that direction. the gray axis is a good enough start for photos
  var direction = normalize(SIMD3<Float>(repeating: 1))
  for _ in 0..<powerIterations {
    let next = covariance * direction
    guard length(next).isApproximatelyGreaterThan(0) else { break }
    direction = normalize(next)
  }

  // how much of the spread that single direction explains
  let explained = dot(direction, covariance * direction)
  return 1 - explained / total
}

private let maxDownsampledDimension = 256
private let powerIterations = 20
private let monochromeThreshold: Float = 0.005
