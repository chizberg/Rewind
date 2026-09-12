//
//  SyntheticImages.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import CoreGraphics
import Foundation
import Testing

func makeRGBImage(width: Int, height: Int, pixels: [[UInt8]]) throws -> CGImage {
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

func makeGrayImage(width: Int, height: Int, values: [UInt8]) throws -> CGImage {
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
