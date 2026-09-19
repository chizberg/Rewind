//
//  ColorizationCheck.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

import Accelerate

// What a colorization came back as: worth showing, or one of the two ways it fails. A model given
// a photo it can make nothing of does not say so — it returns a frame that is all but gray, or one
// tint laid over the whole of it, and both look to a user like a broken app rather than a limit of
// the model. README's "Did the model do its job".
enum ColorizationCheck {
  // The color is worth showing as it is.
  case ok
  // The model found almost no color: the result is the photo with a hint of tint on it.
  case noColor
  // The model painted the whole photo one color instead of coloring the things in it, which is
  // what a sepia or a blue wash coming back from it looks like.
  case onlyTint
}

extension ABPlanes {
  // The chroma of the frame's most colorful pixels under which there is nothing to show. The
  // reference's own bound; for scale, the six parity runs peak between 32 and 87.
  private static let colorlessPeak: Float = 8

  // How much chroma a pixel needs before its hue is worth counting. Below it a pixel is gray and
  // the direction of its (a, b) is arithmetic noise. The reference's own bound, chroma_min=5.
  private static let coloredChroma: Float = 5

  // The hue circle is counted in 36 bins of 10 degrees, and the window a single tint has to fit
  // into is 6 of them: 60 degrees, two thirds of the way from red, which sits at 0, to yellow,
  // which sits at 90. The reference's bins=36, window=6.
  private static let hueBins = 36
  private static let windowBins = 6

  // The share of the colored pixels inside one such window above which the frame is a tint rather
  // than a colorization: spread evenly around the circle they would put a sixth of themselves in
  // any 60 degrees. The reference's own bound.
  private static let tintedShare: Float = 0.85

  // With fewer colored pixels than this the share would be read off a handful of them, and the
  // frame is called a tint instead of measured. On a photograph the case cannot come up: the peak
  // is checked first, and a peak of 8 means a percent of the frame is at least that colorful,
  // which is far more than 64 pixels on anything larger than a thumbnail. The reference's own
  // guard, where it returns a concentration of 1.
  private static let leastColoredPixels = 64

  // Whether the color of this frame is worth showing. Asked of what the model predicted rather
  // than of what compose is handed, because both bounds above are absolute — a pixel counts as
  // colored at chroma 5, a frame as colorless under 8 — while the post-process rescales the whole
  // frame by constants of ours: the ceiling divides it by whatever it takes to fit (×0.41 on one
  // parity frame) and boldness multiplies it by the model's gain. Measured after that, the same
  // frames come out with 0.004 to 0.18 more of their color inside one window of hue, because the
  // pixels the scaling pushed under 5 stop counting. The reference's bounds were measured where
  // this asks them, and on the six parity runs the two places answer the same.
  func checkColorization() -> ColorizationCheck {
    if peakChroma < Self.colorlessPeak {
      .noColor
    } else if hueConcentration() > Self.tintedShare {
      .onlyTint
    } else {
      .ok
    }
  }

  // The largest share of the colored pixels any 60 degrees of hue holds: 1 when every one of them
  // is the same color, a sixth when they are spread evenly around the circle.
  private func hueConcentration() -> Float {
    // The hue of every pixel at once, the gray ones included. One vectorized pass over the frame
    // costs a quarter of what calling atan2 for the colored pixels alone does: 9 ms against 38 at
    // -O over 3.1 M pixels that are all colored.
    // https://developer.apple.com/documentation/accelerate/vforce/atan2(x:y:)-1ozt2
    let hues = vForce.atan2(x: a, y: b)
    var bins = [Int](repeating: 0, count: Self.hueBins)
    var colored = 0
    for (index, value) in chroma.values.enumerated() where value > Self.coloredChroma {
      // atan2 answers in -pi...pi, and a full turn added to that puts every hue on one circle
      // before it is binned, the reference's degrees % 360.
      let turn = hues[index] / (2 * .pi) + 1
      bins[Int(turn * Float(Self.hueBins)) % Self.hueBins] += 1
      colored += 1
    }
    guard colored >= Self.leastColoredPixels else {
      return 1
    }

    var largest = 0
    for start in 0..<Self.hueBins {
      largest = max(largest, (start..<start + Self.windowBins).reduce(0) {
        $0 + bins[$1 % Self.hueBins]
      })
    }
    return Float(largest) / Float(colored)
  }
}
