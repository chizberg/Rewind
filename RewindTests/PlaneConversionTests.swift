//
//  PlaneConversionTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import CoreGraphics
@testable import Rewind
import Testing
import UIKit

struct PlaneConversionTests {
  @Test func channelsAreReadAsBytesOverTwoFiftyFive() throws {
    let image = try makeRGBImage(width: 2, height: 1, pixels: [
      [255, 0, 51],
      [0, 128, 255],
    ])

    let planes = try RGBPlanes(cgImage: image, maxSide: 2)

    #expect(planes.size == PlaneSize(width: 2, height: 1))
    #expect(bytes(planes.r) == [255, 0])
    #expect(bytes(planes.g) == [0, 128])
    #expect(bytes(planes.b) == [51, 255])
  }

  @Test func exifOrientationIsAppliedBeforeReading() throws {
    let image = try makeRGBImage(width: 2, height: 1, pixels: [
      [255, 0, 0],
      [0, 0, 255],
    ])
    let rotated = UIImage(cgImage: image, scale: 1, orientation: .right)

    let planes = try RGBPlanes(image: rotated, maxSide: 2)

    #expect(planes.size == PlaneSize(width: 1, height: 2))
    #expect(bytes(planes.r) == [255, 0])
    #expect(bytes(planes.b) == [0, 255])
  }

  @Test func longSideIsCappedAtMaxSide() throws {
    let image = try makeRGBImage(
      width: 8,
      height: 4,
      pixels: Array(repeating: [100, 150, 200], count: 32),
    )

    let planes = try RGBPlanes(cgImage: image, maxSide: 4)

    #expect(planes.size == PlaneSize(width: 4, height: 2))
    #expect(bytes(planes.r) == Array(repeating: 100, count: 8))
    #expect(bytes(planes.g) == Array(repeating: 150, count: 8))
    #expect(bytes(planes.b) == Array(repeating: 200, count: 8))
  }

  @Test func smallerImageIsReadAtItsOwnSize() throws {
    let image = try makeRGBImage(width: 3, height: 2, pixels: Array(repeating: [0, 0, 0], count: 6))

    let planes = try RGBPlanes(cgImage: image, maxSide: 100)

    #expect(planes.size == PlaneSize(width: 3, height: 2))
  }

  @Test func grayscaleSourceIsReadAsNeutralRGB() throws {
    let image = try makeGrayImage(width: 2, height: 1, values: [0, 200])

    let planes = try RGBPlanes(cgImage: image, maxSide: 2)

    #expect(bytes(planes.r) == [0, 200])
    #expect(bytes(planes.g) == [0, 200])
    #expect(bytes(planes.b) == [0, 200])
  }
}

private func bytes(_ values: [Float]) -> [UInt8] {
  values.map { UInt8(($0 * 255).rounded()) }
}

private func makeRGBImage(width: Int, height: Int, pixels: [[UInt8]]) throws -> CGImage {
  let provider = try #require(CGDataProvider(data: Data(pixels.flatMap { $0 + [255] }) as CFData))
  return try #require(CGImage(
    width: width,
    height: height,
    bitsPerComponent: 8,
    bitsPerPixel: 32,
    bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
    provider: provider,
    decode: nil,
    shouldInterpolate: false,
    intent: .defaultIntent,
  ))
}

private func makeGrayImage(width: Int, height: Int, values: [UInt8]) throws -> CGImage {
  let provider = try #require(CGDataProvider(data: Data(values) as CFData))
  return try #require(CGImage(
    width: width,
    height: height,
    bitsPerComponent: 8,
    bitsPerPixel: 8,
    bytesPerRow: width,
    space: CGColorSpaceCreateDeviceGray(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
    provider: provider,
    decode: nil,
    shouldInterpolate: false,
    intent: .defaultIntent,
  ))
}
