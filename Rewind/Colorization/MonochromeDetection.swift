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
    let planes = try RGBPlanes(cgImage: cgImage, maxSide: maxDownsampledDimension)
    let deviation = try deviationFromMonochrome(planes: planes)
    return deviation < monochromeThreshold
  }.value
}

// monochrome image pixels lie on a line in the RGB space
// color image pixels are more like a cloud, so they deviate from a line
// ~0 for monochrome, a regular color image is ~0.1, max is ~2/3
private func deviationFromMonochrome(planes: RGBPlanes) throws -> Float {
  guard planes.size.pixelCount > 2 else {
    throw HandlingError("Too few points to compute deviation")
  }

  // each channel is shifted by its own average, so that the cloud of pixels
  // sits around zero. otherwise the line would be forced to pass through
  // black, and the line of a sepia image does not
  let r = vDSP.add(-vDSP.mean(planes.r), planes.r)
  let g = vDSP.add(-vDSP.mean(planes.g), planes.g)
  let b = vDSP.add(-vDSP.mean(planes.b), planes.b)

  // covariance: rr, gg and bb are how much each channel varies on its own,
  // the rest is how much a pair of channels varies together
  let inverseCount = 1 / Float(planes.size.pixelCount)
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
private let monochromeThreshold: Float = 0.01
