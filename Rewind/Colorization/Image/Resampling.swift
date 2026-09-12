//
//  Resampling.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Foundation

extension Plane<UInt8> {
  // Shrinks the gray frame to the model's input: each pixel is the average of the pixels it covers
  // (cv2.INTER_AREA).
  func resized(target: PlaneSize) -> Plane<UInt8> {
    let columnTaps = areaTaps(from: size.width, to: target.width)
    let rowTaps = areaTaps(from: size.height, to: target.height)

    var narrowed = [Float](repeating: 0, count: target.width * size.height)
    for y in 0..<size.height {
      let sourceRow = y * size.width
      for x in 0..<target.width {
        var sum: Float = 0
        for tap in columnTaps[x] {
          sum += Float(values[sourceRow + tap.index]) * tap.weight
        }
        narrowed[y * target.width + x] = sum
      }
    }

    var resized = [UInt8](repeating: 0, count: target.pixelCount)
    for y in 0..<target.height {
      for x in 0..<target.width {
        var sum: Float = 0
        for tap in rowTaps[y] {
          sum += narrowed[tap.index * target.width + x] * tap.weight
        }
        resized[y * target.width + x] = UInt8(sum.rounded(.toNearestOrEven))
      }
    }
    return Plane(size: target, values: resized)
  }
}

// One source pixel's contribution to an output pixel.
private struct Tap {
  // The source pixel along the axis.
  var index: Int
  // The covered part of the source pixel over the output pixel's width.
  var weight: Float
}

// Which source pixels feed each output pixel along one axis; computed once, reused on every row.
private func areaTaps(from source: Int, to destination: Int) -> [[Tap]] {
  let scale = Double(source) / Double(destination)
  return (0..<destination).map { index in
    let start = Double(index) * scale
    let end = start + scale
    let covered = Int(start.rounded(.down))..<min(Int(end.rounded(.up)), source)
    return covered.map { position in
      let overlap = min(end, Double(position + 1)) - max(start, Double(position))
      return Tap(index: position, weight: Float(overlap / scale))
    }
  }
}
