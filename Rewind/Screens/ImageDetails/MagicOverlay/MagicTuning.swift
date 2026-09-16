//
//  MagicTuning.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

import Foundation

struct MagicTuning {
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
  var dustSpeed: Double
  var dustWander: Double
  var dustFlow: Double
  var dustSparkle: Double
  var exposure: Double
  var wind: Double
  var edge: Double
  var duration: Double

  static let `default` = MagicTuning(
    blur: 20,
    glow: 0.375,
    blobSize: 0.25,
    blobSpread: 0.36,
    blobSpeed: 1.2,
    hueSpeed: 0.23,
    dustGray: 0.55,
    dustAmount: 1,
    dustGap: 60,
    dustSize: 1.3,
    dustSpeed: 1,
    dustWander: 0.5,
    dustFlow: 460,
    dustSparkle: 8,
    exposure: 2,
    wind: 120,
    edge: 400,
    duration: 0.46,
  )
}
