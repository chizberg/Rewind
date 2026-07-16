//
//  GradientSchemeTests.swift
//  RewindTests
//
//  Characterization tests for the year -> colour tinting pipeline:
//  GradientScheme.color(at:maxRange:) (lerpParameter -> clamp -> binSearch ->
//  per-channel lerp) and RGBAColor.isDark (gamma-linearised luminance).
//
//  Expected colours are hand-computed from the interpolation math against the
//  explicit-RGBA schemes (`bw`, `warm`) so the expected value is external, not a
//  re-run of the product transform. The `rewind`/`pastvu` schemes are skipped on
//  purpose: `rewind` is built from UIKit system colours whose exact components
//  are opaque, which would make any expected circular.
//

import CoreGraphics
@testable import Rewind
import Testing
import VGSL

struct GradientSchemeTests {
  private func expectColor(
    _ color: RGBAColor,
    _ r: CGFloat,
    _ g: CGFloat,
    _ b: CGFloat,
    _ a: CGFloat = 1,
    _ comment: Comment? = nil,
  ) {
    #expect(color.red.isApproximatelyEqualTo(r), comment)
    #expect(color.green.isApproximatelyEqualTo(g), comment)
    #expect(color.blue.isApproximatelyEqualTo(b), comment)
    #expect(color.alpha.isApproximatelyEqualTo(a), comment)
  }

  // bw = [(0, black), (1, white)]; the year lands exactly on each endpoint.
  @Test func endpointsAreExactStops() {
    expectColor(GradientScheme.bw.color(at: 1826, maxRange: 1826...2000), 0, 0, 0)
    expectColor(GradientScheme.bw.color(at: 2000, maxRange: 1826...2000), 1, 1, 1)
  }

  // Years outside maxRange must clamp to the boundary stop, never extrapolate.
  @Test func clampsOutsideRange() {
    expectColor(
      GradientScheme.bw.color(at: 1700, maxRange: 1826...2000),
      0,
      0,
      0,
      1,
      "below -> first"
    )
    expectColor(
      GradientScheme.bw.color(at: 2100, maxRange: 1826...2000),
      1,
      1,
      1,
      1,
      "above -> last"
    )
  }

  // t = (1913 - 1826) / (2000 - 1826) = 87/174 = 0.5 -> mid grey on the bw ramp.
  @Test func bwMidpointIsGrey() {
    expectColor(GradientScheme.bw.color(at: 1913, maxRange: 1826...2000), 0.5, 0.5, 0.5)
  }

  // t = 375/1000 = 0.375 lands between warm stops at 0.25 and 0.50, at t1 = 0.5.
  // r = lerp(.5, .60, .80) = .70; g = lerp(.5, .15, .30) = .225; b = lerp(.5, .15, .20) = .175.
  @Test func warmInteriorSegmentInterpolates() {
    expectColor(GradientScheme.warm.color(at: 375, maxRange: 0...1000), 0.70, 0.225, 0.175)
  }

  // isDark uses sRGB-gamma-linearised relative luminance, not raw channel means.
  // Black/white are the obvious ends; the greys straddle the perceptual 0.5
  // threshold and would flip if the gamma linearisation were dropped:
  // mid grey linearises to ~0.21 (dark), 0.75 grey to ~0.52 (light).
  @Test func isDarkUsesLinearisedLuminance() {
    #expect(RGBAColor(red: 0, green: 0, blue: 0, alpha: 1).isDark)
    #expect(!RGBAColor(red: 1, green: 1, blue: 1, alpha: 1).isDark)
    #expect(RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1).isDark)
    #expect(!RGBAColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1).isDark)
  }
}
