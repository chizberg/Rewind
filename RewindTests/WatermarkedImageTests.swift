//
//  WatermarkedImageTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

@testable import Rewind
import Testing
import UIKit

struct WatermarkedImageTests {
  @Test func stitchingTheSplitContentBackGivesTheOriginal() async throws {
    let original: [[UInt8]] = [
      [255, 0, 51], [0, 128, 255],
      [17, 34, 68], [136, 204, 85],
      [240, 120, 60], [5, 250, 190],
    ]
    let image = try UIImage(
      cgImage: makeRGBImage(width: 2, height: 3, pixels: original),
      scale: 2,
      orientation: .up,
    )

    let split = await splitWatermark(from: image, watermarkHeight: 1, contentHeight: 2)
    try #require(split.watermark != nil)
    let stitched = await split.stitched()

    #expect(stitched.scale == image.scale)
    #expect(stitched.cgImage?.width == 2)
    #expect(stitched.cgImage?.height == 3)
    #expect(try pixels(of: stitched) == original)
  }

  @Test func stripIsFittedToANarrowerContent() async throws {
    let color: [UInt8] = [200, 120, 40]
    let stripColor: [UInt8] = [10, 20, 30]
    let source = try WatermarkedImage(
      content: UIImage(cgImage: makeRGBImage(width: 2, height: 1, pixels: [color, color])),
      watermark: UIImage(cgImage: makeRGBImage(
        width: 4,
        height: 2,
        pixels: Array(repeating: stripColor, count: 8),
      )),
    )

    let stitched = await source.stitched()

    #expect(stitched.cgImage?.width == 2)
    #expect(stitched.cgImage?.height == 2)
    #expect(try pixels(of: stitched) == [color, color, stripColor, stripColor])
  }
}

private func pixels(of image: UIImage) throws -> [[UInt8]] {
  let cgImage = try #require(image.cgImage)
  let planes = try RGBPlanes(cgImage: cgImage, maxSide: max(cgImage.width, cgImage.height))
  return (0..<planes.size.pixelCount).map { i in
    [planes.r[i], planes.g[i], planes.b[i]].map(ColorizationHelpers.byte(sRGB:))
  }
}
