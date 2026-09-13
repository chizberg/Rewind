//
//  Colorize.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

import UIKit

// The whole pipeline in the order of README's diagram, one stage a line: every new stage lands
// here as one more line. Nonisolated and async, so the pixel work runs on the global executor
// rather than on the main actor the tap came from.
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md
func colorize(image: UIImage, with model: some ColorizationModel) async throws -> UIImage {
  let source = try RGBPlanes(image: image, maxSide: maxSide)
  let lightness = Lab.lightness(of: source)
  let gray = CLAHE.apply(to: Lab.neutralGray(lightness: lightness), clip: model.claheClip)
  let ab = try await model.predict(gray: gray)
  return try Lab.rgb(lightness: lightness, ab: ab).makeUIImage()
}

// The cap on the long side the photo is read at; the model's own geometry starts from here.
private let maxSide = 2048
