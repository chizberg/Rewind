//
//  Resampling.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Foundation
import VGSL

extension Plane<UInt8> {
  // Shrinks the gray frame to the model's input: each pixel is the average of the pixels it covers
  // (cv2.INTER_AREA).
  // https://docs.opencv.org/4.x/da/d54/group__imgproc__transform.html#ga47a974309e9102f5f08231edc7e7529d
  func resized(target: PlaneSize) -> Plane<UInt8> {
    resampled(
      target: target,
      columnTaps: areaTaps(from: size.width, to: target.width),
      rowTaps: areaTaps(from: size.height, to: target.height),
      betweenPasses: { $0 },
    )
  }

  // Squashes the gray frame into ECCV16's square the way the reference made that model's input:
  // Pillow's BICUBIC resize, rounded to bytes after the horizontal pass and after the vertical.
  // https://pillow.readthedocs.io/en/stable/handbook/concepts.html#filters
  func bicubicResized(target: PlaneSize) -> Plane<UInt8> {
    resampled(
      target: target,
      columnTaps: cubicTaps(from: size.width, to: target.width),
      rowTaps: cubicTaps(from: size.height, to: target.height),
      betweenPasses: { $0.rounded().clamp(0...255) },
    )
  }

  // Fills the model's fixed input by mirroring the frame right and down, keeping its proportions
  // (cv2.BORDER_REFLECT_101).
  // https://docs.opencv.org/4.x/d2/de8/group__core__array.html#ga209f2f4869e304c82d07739337eae7c5
  func padded(target: PlaneSize) -> Plane<UInt8> {
    assert(target.width >= size.width && target.height >= size.height)
    let columns = (0..<target.width)
      .map { ColorizationHelpers.mirroredIndex($0, limit: size.width) }
    var padded = [UInt8](repeating: 0, count: target.pixelCount)
    for y in 0..<target.height {
      let sourceRow = ColorizationHelpers.mirroredIndex(y, limit: size.height) * size.width
      for x in 0..<target.width {
        padded[y * target.width + x] = values[sourceRow + columns[x]]
      }
    }
    return Plane(size: target, values: padded)
  }

  // Both resizes in two passes, columns into a buffer and then rows, as OpenCV and Pillow separate
  // them; `betweenPasses` is what each library does to the buffer: floats kept, or bytes.
  private func resampled(
    target: PlaneSize,
    columnTaps: [[Tap]],
    rowTaps: [[Tap]],
    betweenPasses: (Float) -> Float,
  ) -> Plane<UInt8> {
    var narrowed = [Float](repeating: 0, count: target.width * size.height)
    for y in 0..<size.height {
      let sourceRow = y * size.width
      for x in 0..<target.width {
        var sum: Float = 0
        for tap in columnTaps[x] {
          sum += Float(values[sourceRow + tap.index]) * tap.weight
        }
        narrowed[y * target.width + x] = betweenPasses(sum)
      }
    }

    var resized = [UInt8](repeating: 0, count: target.pixelCount)
    for y in 0..<target.height {
      for x in 0..<target.width {
        var sum: Float = 0
        for tap in rowTaps[y] {
          sum += narrowed[tap.index * target.width + x] * tap.weight
        }
        resized[y * target.width + x] = UInt8(sum.rounded().clamp(0...255))
      }
    }
    return Plane(size: target, values: resized)
  }
}

// One source pixel's contribution to an output pixel.
private struct Tap {
  // The source pixel along the axis.
  var index: Int
  // The source pixel's share of the output pixel; the shares of one output pixel sum to 1.
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

// Pillow's bicubic weights along one axis: Keys' cubic kernel with a = -0.5, spelled as Pillow's
// bicubic_filter, widened by the scale when shrinking so every source pixel under the output pixel
// counts, the weights of each output pixel normalized to sum to 1.
// https://doi.org/10.1109/TASSP.1981.1163711
private func cubicTaps(from source: Int, to destination: Int) -> [[Tap]] {
  let a = -0.5
  let kernelSupport = 2.0
  func cubic(_ distance: Double) -> Double {
    let x = abs(distance)
    if x < 1 { return ((a + 2) * x - (a + 3)) * x * x + 1 }
    if x < kernelSupport { return (((x - 5) * x + 8) * x - 4) * a }
    return 0
  }
  let scale = Double(source) / Double(destination)
  let stretch = max(scale, 1)
  let support = kernelSupport * stretch
  return (0..<destination).map { index in
    let center = (Double(index) + 0.5) * scale
    let covered = max(0, Int(center - support + 0.5))..<min(Int(center + support + 0.5), source)
    let weights = covered.map { cubic((Double($0) - center + 0.5) / stretch) }
    let total = weights.reduce(0, +)
    return zip(covered, weights).map { Tap(index: $0, weight: Float($1 / total)) }
  }
}
