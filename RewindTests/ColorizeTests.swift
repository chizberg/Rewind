//
//  ColorizeTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

@testable import Rewind
import Testing
import UIKit

struct ColorizeTests {
  @Test(arguments: ColorizationParityTests.frames, ColorizationModelID.allCases)
  func colorlessPredictionComposesTheFrameNeutralGray(
    _ frame: String,
    _ measuredModel: ColorizationModelID,
  ) async throws {
    let reference = try ParityReference.load()
    let image = try reference.input(frame: frame)
    let model = try ColorlessModel(
      claheClip: reference.expected(frame: frame, model: measuredModel).claheClip,
    )

    let colorized = try await colorize(image: image, with: model)

    let prepared = try reference.prepared(frame: frame, claheClip: model.claheClip)
    let received = try #require(await model.receivedGray)
    #expect(received.size == prepared.gray.size)
    #expect(received.values == prepared.gray.values)
    let composed = try RGBPlanes(image: colorized, maxSide: reference.longSide)
    #expect(composed.size == prepared.gray.size)
    let gray = Lab.neutralGray(lightness: prepared.lightness).values
    for channel in [composed.r, composed.g, composed.b] {
      let deviations = zip(channel, gray).map {
        abs(Int(ColorizationHelpers.byte(sRGB: $0)) - Int($1))
      }
      #expect((deviations.max() ?? 0) <= 1)
    }
  }
}
