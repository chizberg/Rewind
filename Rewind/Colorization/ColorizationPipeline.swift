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
}
