//
//  ColorizationCheckTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

import Foundation
@testable import Rewind
import Testing
import UIKit

struct ColorizationCheckTests {
  private static let hues = 360
  private static let coloredStride = 10
  private static let size = PlaneSize(width: hues * coloredStride, height: 1)
  private static let faintChroma: Float = 7
  private static let grayChroma: Float = 1
  private static let strongChroma: Float = 20
  private static let tintHue: Float = 40
  private static let hueBeforeZero: Float = 355
  private static let hueAfterZero: Float = 5
  private static let tooFewColored = 40
  private static let photoSide = 64
  private static let photoGray: UInt8 = 128
  private static let claheClip = 1.0

  @Test func aFrameThatCameBackAlmostGrayIsReportedAsNoColor() {
    let ab = Self.planes { index in (Float(index % Self.hues), Self.faintChroma) }

    #expect(ab.checkColorization() == .noColor)
  }

  @Test func oneHueOverTheWholeFrameIsReportedAsOnlyATint() {
    let ab = Self.planes { _ in (Self.tintHue, Self.strongChroma) }

    #expect(ab.checkColorization() == .onlyTint)
  }

  @Test func colorsSpreadAroundTheCircleComeBackOk() {
    let ab = Self.planes { index in (Float(index % Self.hues), Self.strongChroma) }

    #expect(ab.checkColorization() == .ok)
  }

  @Test func aTintSplitAcrossTheStartOfTheCircleIsStillATint() {
    let ab = Self.planes { index in
      (index.isMultiple(of: 2) ? Self.hueBeforeZero : Self.hueAfterZero, Self.strongChroma)
    }

    #expect(ab.checkColorization() == .onlyTint)
  }

  @Test func theGrayPixelsDoNotCountTowardsTheTint() {
    let ab = Self.planes { index in
      index.isMultiple(of: Self.coloredStride)
        ? (Float(index % Self.hues), Self.strongChroma)
        : (Self.tintHue, Self.grayChroma)
    }

    #expect(ab.checkColorization() == .ok)
  }

  @Test func tooFewColoredPixelsToJudgeCountAsATint() {
    let ab = Self.planes { index in
      index < Self.tooFewColored
        ? (Float(index) * Float(Self.hues) / Float(Self.tooFewColored), Self.strongChroma)
        : (Self.tintHue, 0)
    }

    #expect(ab.checkColorization() == .onlyTint)
  }

  @Test func theColorIsJudgedBeforeTheGainCanLiftItOverTheBound() async throws {
    let model = FaintColorModel()
    let photo = try Self.flatGrayPhoto()

    let (_, check) = try await colorize(image: photo, model: model)

    #expect(check == .noColor)
    let lightness = try Lab.lightness(of: RGBPlanes(image: photo, maxSide: Self.photoSide))
    let ab = await model.predict(gray: Lab.neutralGray(lightness: lightness))
    let anchored = try EdgeAwareBlur.apply(to: ab, lightness: lightness)
    let bolder = Boldness.apply(to: anchored, lightness: lightness, boldness: model.boldness)
    let capped = ChromaCeiling.apply(to: bolder, boldness: model.boldness)
    #expect(capped.checkColorization() == .ok)
  }

  @Test func aRunOfAModelThatPredictsNoColorSaysSo() async throws {
    let model = ColorlessModel(claheClip: Self.claheClip)

    let (_, check) = try await colorize(image: makeTinyPhoto(), model: model)

    #expect(check == .noColor)
  }

  private static func flatGrayPhoto() throws -> UIImage {
    try UIImage(cgImage: makeGrayImage(
      width: photoSide,
      height: photoSide,
      values: [UInt8](repeating: photoGray, count: photoSide * photoSide),
    ))
  }

  private static func planes(_ color: (Int) -> (hue: Float, chroma: Float)) -> ABPlanes {
    let pixels = (0..<size.pixelCount).map(color)
    return ABPlanes(
      size: size,
      a: pixels.map { $0.chroma * cos($0.hue * .pi / 180) },
      b: pixels.map { $0.chroma * sin($0.hue * .pi / 180) },
    )
  }
}
