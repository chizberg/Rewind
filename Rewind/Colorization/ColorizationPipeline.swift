//
//  ColorizationPipeline.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import UIKit

enum ColorizationPipeline {
  static let maxSide = 2048

  struct Input {
    var gray: Plane<UInt8>
    var lightness: Plane<Float>
  }

  static func prepare(image: UIImage, claheClip: Double) throws -> Input {
    let source = try RGBPlanes(image: image, maxSide: maxSide)
    let lightness = Lab.lightness(of: source)
    return Input(
      gray: CLAHE.apply(to: Lab.neutralGray(lightness: lightness), clip: claheClip),
      lightness: lightness,
    )
  }

  // One photo colorized: prepare, the model's ab, finish. Nonisolated and async, so the pixel work
  // runs on the global executor rather than on the main actor the tap came from.
  // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md
  static func run(_ model: some ColorizationModel, image: UIImage) async throws -> UIImage {
    let input = try prepare(image: image, claheClip: model.claheClip)
    let ab = try await model.predict(gray: input.gray)
    return try finish(input, ab: ab)
  }

  // Everything after the model: composing the photo's own lightness with the model's ab.
  private static func finish(_ input: Input, ab: ABPlanes) throws -> UIImage {
    try Lab.rgb(lightness: input.lightness, ab: ab).makeUIImage()
  }
}
