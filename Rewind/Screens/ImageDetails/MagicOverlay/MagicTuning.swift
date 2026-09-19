//
//  MagicTuning.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

import Foundation

struct MagicTuning: Equatable {
  var blur: Double
  var glow: Double
  var blobSize: Double
  var blobSpread: Double
  var blobSpeed: Double
  var hueSpeed: Double
  var dustGray: Double
  var dustAmount: Double
  var dustGap: Double
  var dustSize: Double
  var dustLife: Double
  var dustSpeed: Double
  var dustWander: Double
  var dustFlow: Double
  var sparkleShare: Double
  var sparkleLife: Double
  var exposure: Double
  var wind: Double
  var edge: Double
  var duration: Double

  static let `default` = MagicTuning(
    blur: 10,
    glow: 0.38,
    blobSize: 0.25,
    blobSpread: 0.36,
    blobSpeed: 0.79,
    hueSpeed: 0.33,
    dustGray: 0.55,
    dustAmount: 1,
    dustGap: 60,
    dustSize: 2.2,
    dustLife: 6.2,
    dustSpeed: 0.39,
    dustWander: 51,
    dustFlow: 595,
    sparkleShare: 0.27,
    sparkleLife: 0.75,
    exposure: 2,
    wind: 120,
    edge: 400,
    duration: 0.46,
  )
}
