//
//  CLAHE.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import Foundation

// Contrast Limited Adaptive Histogram Equalization (Zuiderveld, Graphics Gems IV, 1994): the frame
// is cut into a grid of tiles, each tile's histogram is equalized on its own, the stretch of any
// one level is capped, and every pixel blends the tables of the four tiles around it so the grid
// does not show. Written after OpenCV's clahe.cpp step by step, because the reference pipeline
// runs cv2.createCLAHE(clipLimit, tileGridSize: (8, 8)) on the L channel of an 8-bit Lab frame
// and every parity number carries its exact arithmetic:
// https://github.com/opencv/opencv/blob/4.x/modules/imgproc/src/clahe.cpp
enum CLAHE {
  private static let gridSize = 8
  private static let histogramSize = 256

  // `clip` is OpenCV's clipLimit: how many times the average bin one histogram bin may hold.
  // The gray frame is neutral, so RGB -> Lab -> L is one table lookup and the way back another.
  static func apply(to gray: Plane<UInt8>, clip: Double) -> Plane<UInt8> {
    let lightness = gray.map { Lab.grayToLightnessByte[Int($0)] }
    return equalize(lightness, clip: clip).map { Lab.lightnessByteToGray[Int($0)] }
  }

  private static func equalize(_ lightness: Plane<UInt8>, clip: Double) -> Plane<UInt8> {
    let width = lightness.size.width
    let height = lightness.size.height

    // OpenCV pads the frame up to a whole number of tiles, and on both axes as soon as either
    // one needs it, so a width already divisible by 8 still gains 8 pixels, one per tile. The
    // pad is never built: `mirroredIndex` reads it out of the original.
    let fitsWholeTiles = width % gridSize == 0 && height % gridSize == 0
    let paddedWidth = fitsWholeTiles ? width : width + gridSize - width % gridSize
    let paddedHeight = fitsWholeTiles ? height : height + gridSize - height % gridSize
    let tileWidth = paddedWidth / gridSize
    let tileHeight = paddedHeight / gridSize
    let tileArea = tileWidth * tileHeight

    // tileArea / histogramSize is the average bin; static_cast<int> in OpenCV, so truncation,
    // then at least one count per bin.
    let limit = max(Int(clip * Double(tileArea) / Double(histogramSize)), 1)

    // One 256-entry table per tile, stored flat in row-major tile order.
    var tables = [UInt8]()
    tables.reserveCapacity(gridSize * gridSize * histogramSize)
    for tileY in 0..<gridSize {
      for tileX in 0..<gridSize {
        var histogram = [Int](repeating: 0, count: histogramSize)
        for y in 0..<tileHeight {
          let row = ColorizationHelpers.mirroredIndex(tileY * tileHeight + y, limit: height) * width
          for x in 0..<tileWidth {
            let column = ColorizationHelpers.mirroredIndex(tileX * tileWidth + x, limit: width)
            histogram[Int(lightness.values[row + column])] += 1
          }
        }
        tables.append(contentsOf: makeTable(histogram: histogram, limit: limit, tileArea: tileArea))
      }
    }

    // The reciprocals are OpenCV's, a division would land some boundary pixels one tile over.
    let inverseTileWidth = 1 / Float(tileWidth)
    let inverseTileHeight = 1 / Float(tileHeight)
    let tileColumns = (0..<width).map { x in neighborTiles(at: Float(x) * inverseTileWidth) }
    var equalized = [UInt8](repeating: 0, count: lightness.size.pixelCount)
    for y in 0..<height {
      let tileRows = neighborTiles(at: Float(y) * inverseTileHeight)
      for x in 0..<width {
        let tileColumn = tileColumns[x]
        let value = Int(lightness.values[y * width + x])
        func table(_ row: Int, _ column: Int) -> Float {
          Float(tables[(row * gridSize + column) * histogramSize + value])
        }
        let fromFirstRow = blend(
          table(tileRows.first, tileColumn.first),
          table(tileRows.first, tileColumn.second),
          weight: tileColumn.weight,
        )
        let fromSecondRow = blend(
          table(tileRows.second, tileColumn.first),
          table(tileRows.second, tileColumn.second),
          weight: tileColumn.weight,
        )
        let blended = blend(fromFirstRow, fromSecondRow, weight: tileRows.weight)
        // Halves round away from zero, where OpenCV's saturate_cast rounds them to even: about
        // 0.2% of pixels come out one level lighter, the parity mean moves by 0.002.
        equalized[y * width + x] = UInt8(blended.rounded())
      }
    }
    return Plane(size: lightness.size, values: equalized)
  }

  // One tile's table: clip the histogram at `limit`, hand the clipped counts back to all bins,
  // then integrate. The running sum scaled to 0...255 is the equalization map: a level is sent
  // to the share of the tile's pixels at or below it.
  private static func makeTable(histogram: [Int], limit: Int, tileArea: Int) -> [UInt8] {
    var histogram = histogram
    var clipped = 0
    for i in 0..<histogramSize where histogram[i] > limit {
      clipped += histogram[i] - limit
      histogram[i] = limit
    }

    // OpenCV's redistribution, reproduced literally: an even share to every bin, and the
    // remainder, under 256 counts, one per bin at a stride rather than onto the first bins.
    let batch = clipped / histogramSize
    var residual = clipped - batch * histogramSize
    for i in 0..<histogramSize {
      histogram[i] += batch
    }
    if residual > 0 {
      let step = max(histogramSize / residual, 1)
      var i = 0
      while i < histogramSize, residual > 0 {
        histogram[i] += 1
        residual -= 1
        i += step
      }
    }

    let scale = Float(histogramSize - 1) / Float(tileArea)
    var table = [UInt8](repeating: 0, count: histogramSize)
    var sum = 0
    for i in 0..<histogramSize {
      sum += histogram[i]
      table[i] = UInt8((Float(sum) * scale).rounded())
    }
    return table
  }

  // The two tile centres a pixel lies between along one axis, and how far it is towards the
  // second. `position` is the pixel coordinate in tiles; the -0.5 moves it to tile-centre
  // coordinates, so at a tile's centre the pixel takes that tile's table alone. The weight is
  // taken before the indices are clamped, so a pixel before the first centre or past the last
  // one gets the edge tile alone.
  private struct NeighborTiles {
    var first: Int
    var second: Int
    var weight: Float
  }

  private static func neighborTiles(at position: Float) -> NeighborTiles {
    let centered = position - 0.5
    let first = Int(centered.rounded(.down))
    return NeighborTiles(
      first: max(first, 0),
      second: min(first + 1, gridSize - 1),
      weight: centered - Float(first),
    )
  }

  private static func blend(_ a: Float, _ b: Float, weight: Float) -> Float {
    a * (1 - weight) + b * weight
  }
}
