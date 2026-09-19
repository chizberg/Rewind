//
//  Colorize.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

import UIKit

// The whole pipeline in the order of README's diagram, one stage a line: every new stage lands
// here as one more line. Nonisolated and async, so the pixel work runs on the global executor
// rather than on the main actor the tap came from. Out comes the colorized photo and whether the
// model colored it or failed it.
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md
func colorize(
  image: UIImage,
  model: some ColorizationModel,
) async throws -> (image: UIImage, check: ColorizationCheck) {
  try Task.checkCancellation()
  let source = try RGBPlanes(image: image, maxSide: maxSide)
  let lightness = Lab.lightness(of: source)
  try Task.checkCancellation()
  let stretched = Levels.stretch(lightness: lightness)
  try Task.checkCancellation()
  let gray = CLAHE.apply(to: Lab.neutralGray(lightness: stretched), clip: model.claheClip)
  try Task.checkCancellation()

  let ab = try await model.predict(gray: gray)
  try Task.checkCancellation()

  let check = ab.checkColorization()
  try Task.checkCancellation()

  // post-processing
  let anchored = try EdgeAwareBlur.apply(to: ab, lightness: stretched)
  try Task.checkCancellation()
  let bolder = Boldness.apply(to: anchored, lightness: stretched, boldness: model.boldness)
  try Task.checkCancellation()
  let capped = ChromaCeiling.apply(to: bolder, boldness: model.boldness)
  try Task.checkCancellation()

  let colorized = try Lab.rgb(lightness: stretched, ab: capped).makeUIImage()
  return (image: colorized, check: check)
}

// The cap on the long side the photo is read at; the model's own geometry starts from here.
private let maxSide = 2048
