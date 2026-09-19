//
//  ColorizationParityTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import CoreML
@testable import Rewind
import Testing
import UIKit

@Suite(.serialized)
struct ColorizationParityTests {
  static let frames = ["2209460", "2504212", "166360"]
  static let lightnessTolerance = 0.15
  static let peakTolerance: Float = 0.05
  private static let tintedFrame = "166360"
  private static let tintedGrayTolerance = 0.25
  private static let tintedStretchTolerance = 0.75
  private static let tintedClaheTolerance = 1.25
  private static let tintedStrongClaheTolerance = 2.5
  private static let tintedStrongClaheExtremeTolerance = 2.5
  private static let crushedShare = 0.005...0.015
  private static let scaleBottom: Float = 0
  private static let scaleTop: Float = 100

  @Test(arguments: frames)
  func grayFrame(_ frame: String) throws {
    let reference = try ParityReference.load()
    let expected = try reference.expected(frame: frame, model: .ddColorLarge)

    let gray = try reference.gray(frame: frame)

    try expected.check(
      "1_to_gray_rgb",
      ParityStatistics(bytes: gray.values),
      momentTolerance: frame == Self.tintedFrame
        ? Self.tintedGrayTolerance
        : ParityReference.Case.momentTolerance,
    )
  }

  @Test(arguments: frames, ColorizationModelID.allCases)
  func preparedFrame(_ frame: String, _ model: ColorizationModelID) throws {
    let reference = try ParityReference.load()
    let expected = try reference.expected(frame: frame, model: model)

    let tinted = frame == Self.tintedFrame
    let claheTolerance = switch (tinted, model) {
    case (false, _): ParityReference.Case.momentTolerance
    case (true, .ddColorLarge): Self.tintedClaheTolerance
    case (true, .eccv16): Self.tintedStrongClaheTolerance
    }
    let claheExtremeTolerance = tinted && model == .eccv16
      ? Self.tintedStrongClaheExtremeTolerance
      : ParityReference.Case.extremeTolerance

    let prepared = try reference.prepared(
      frame: frame,
      claheClip: expected.claheClip,
      levels: expected.levels,
    )

    if expected.levels {
      try expected.check(
        "2_levels_rgb",
        ParityStatistics(bytes: Lab.neutralGray(lightness: prepared.lightness).values),
        momentTolerance: tinted
          ? Self.tintedStretchTolerance
          : ParityReference.Case.momentTolerance,
      )
      let atTheBottom = Self.share(of: prepared.lightness, at: Self.scaleBottom)
      let atTheTop = Self.share(of: prepared.lightness, at: Self.scaleTop)
      #expect(Self.crushedShare.contains(atTheBottom), "share at 0 \(atTheBottom)")
      #expect(Self.crushedShare.contains(atTheTop), "share at 100 \(atTheTop)")
    }

    try expected.check(
      "3_clahe_rgb",
      ParityStatistics(bytes: prepared.gray.values),
      momentTolerance: claheTolerance,
      extremeTolerance: claheExtremeTolerance,
    )
    try expected.check(
      "5_L",
      ParityStatistics(prepared.lightness.values),
      momentTolerance: Self.lightnessTolerance,
    )
    let weight = Boldness.lightnessWeight(prepared.lightness)
    try expected.check("7_lum_weight", ParityStatistics(weight.values))
  }

  @Test(.enabled(if: TestModel.isAvailable(.ddColorLarge)), arguments: frames)
  func ddColorLargePrediction(_ frame: String) async throws {
    try await checkPrediction(
      frame: frame,
      model: .ddColorLarge,
      peakChromaDrop: 0.03,
      boldChromaLift: 0.05,
    ) { url, gray in
      try await DDColorLarge(modelURL: url).predict(gray: gray)
    }
  }

  @Test(.enabled(if: TestModel.isAvailable(.eccv16)), arguments: frames)
  func eccv16Prediction(_ frame: String) async throws {
    try await checkPrediction(
      frame: frame,
      model: .eccv16,
      peakChromaDrop: 0.001,
      boldChromaLift: 0,
    ) { url, gray in
      try await ECCV16(modelURL: url).predict(gray: gray)
    }
  }

  private func checkPrediction(
    frame: String,
    model: ColorizationModelID,
    peakChromaDrop: Double,
    boldChromaLift: Double,
    predict: (URL, Plane<UInt8>) async throws -> ABPlanes,
  ) async throws {
    let reference = try ParityReference.load()
    let expected = try reference.expected(frame: frame, model: model)
    let prepared = try reference.prepared(
      frame: frame,
      claheClip: expected.claheClip,
      levels: expected.levels,
    )
    let compiled = try await TestModel.compile(model)
    defer { try? FileManager.default.removeItem(at: compiled) }

    let ab = try await predict(compiled, prepared.gray)

    #expect(ab.size == prepared.gray.size)
    expected.checkModelMean("4_model_ab_a", ParityStatistics(ab.a))
    expected.checkModelMean("4_model_ab_b", ParityStatistics(ab.b))
    let chroma = ParityStatistics(ab.chroma.values)
    expected.checkModelMean("4_model_chroma", chroma)

    let anchored = try EdgeAwareBlur.apply(to: ab, lightness: prepared.lightness)
    let anchoredChroma = ParityStatistics(anchored.chroma.values)
    expected.checkModelMean("6_bilateral_chroma", anchoredChroma)
    #expect(
      anchoredChroma.maximum < chroma.maximum * (1 - peakChromaDrop),
      "peak chroma \(chroma.maximum) -> \(anchoredChroma.maximum)",
    )

    let castRatio = Boldness.castRatio(of: anchored)
    try expected.checkModelScalar("7_cast_ratio", Double(castRatio))
    let requested = try Float(expected.scalar("7_bold_in"))
    try expected.checkModelScalar(
      "7_bold_effective",
      Double(Boldness.effectiveBoldness(requested, castRatio: castRatio)),
    )

    let bolder = Boldness.apply(to: anchored, lightness: prepared.lightness, boldness: requested)
    let bolderChroma = ParityStatistics(bolder.chroma.values)
    expected.checkModelMean("7_bold_chroma", bolderChroma)
    #expect(
      bolderChroma.mean >= anchoredChroma.mean * (1 + boldChromaLift),
      "mean chroma \(anchoredChroma.mean) -> \(bolderChroma.mean)",
    )

    let ceiling = ChromaCeiling.limit(boldness: requested)
    try #expect(Double(ceiling) == expected.scalar("8_cap"))
    let capped = ChromaCeiling.apply(to: bolder, boldness: requested)
    expected.checkModelMean("8_cap_chroma", ParityStatistics(capped.chroma.values))
    let cappedPeak = ChromaCeiling.peakChroma(of: capped)
    #expect(
      abs(cappedPeak - ceiling) < Self.peakTolerance,
      "peak chroma \(ChromaCeiling.peakChroma(of: bolder)) -> \(cappedPeak) against \(ceiling)",
    )

    let composed = Lab.rgb(lightness: prepared.lightness, ab: capped)
    let red = Self.bytes(of: composed.r)
    let green = Self.bytes(of: composed.g)
    let blue = Self.bytes(of: composed.b)
    expected.checkModelMean("10_final_R", ParityStatistics(red))
    expected.checkModelMean("10_final_G", ParityStatistics(green))
    expected.checkModelMean("10_final_B", ParityStatistics(blue))
    expected.checkModelMean("10_final_rgb", ParityStatistics(red + green + blue))
  }

  private static func bytes(of channel: [Float]) -> [Float] {
    channel.map { Float(ColorizationHelpers.byte(sRGB: $0)) }
  }

  private static func share(of plane: Plane<Float>, at value: Float) -> Double {
    Double(plane.values.count { $0 == value }) / Double(plane.size.pixelCount)
  }
}

enum TestModel {
  static func isAvailable(_ id: ColorizationModelID) -> Bool {
    packageURL(id).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
  }

  static func compile(_ id: ColorizationModelID) async throws -> URL {
    try await MLModel.compileModel(at: #require(packageURL(id)))
  }

  private static func packageURL(_ id: ColorizationModelID) -> URL? {
    ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"].map { home in
      URL(filePath: home).appending(path: "Junk/models").appending(path: id.packageName)
    }
  }
}

struct ParityReference: Decodable {
  enum Stage: Decodable {
    case statistics(ParityStatistics)
    case scalar(Double)
    case other

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(ParityStatistics.self) {
        self = .statistics(value)
      } else if let value = try? container.decode(Double.self) {
        self = .scalar(value)
      } else {
        self = .other
      }
    }
  }

  struct Case: Decodable {
    var claheClip: Double
    var levels: Bool
    var stages: [String: Stage]

    enum CodingKeys: String, CodingKey {
      case claheClip = "clahe"
      case levels
      case stages
    }
  }

  var longSide: Int
  var cases: [String: Case]

  enum CodingKeys: String, CodingKey {
    case longSide = "long_side"
    case cases
  }

  static func load() throws -> ParityReference {
    try JSONDecoder().decode(
      ParityReference.self,
      from: Fixture.data("ios-parity/reference.json"),
    )
  }

  func expected(frame: String, model: ColorizationModelID) throws -> Case {
    try #require(cases["\(frame)|\(model.rawValue)"], "no \(frame) case for \(model)")
  }

  func input(frame: String) throws -> UIImage {
    try #require(UIImage(contentsOfFile: Fixture.url("ios-parity/\(frame)-input.png").path))
  }

  func gray(frame: String) throws -> Plane<UInt8> {
    let source = try RGBPlanes(image: input(frame: frame), maxSide: longSide)
    return Lab.neutralGray(lightness: Lab.lightness(of: source))
  }

  func prepared(
    frame: String,
    claheClip: Double,
    levels: Bool,
  ) throws -> (gray: Plane<UInt8>, lightness: Plane<Float>) {
    let source = try RGBPlanes(image: input(frame: frame), maxSide: longSide)
    let lightness = Lab.lightness(of: source)
    let stretched = levels ? Levels.stretch(lightness: lightness) : lightness
    return (CLAHE.apply(to: Lab.neutralGray(lightness: stretched), clip: claheClip), stretched)
  }
}

extension ParityReference.Case {
  static let momentTolerance = 0.05
  static let extremeTolerance = 1.0
  static let modelMeanAbsoluteTolerance = 1.5
  static let modelRelativeTolerance = 0.25

  func check(
    _ stage: String,
    _ measured: ParityStatistics,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) throws {
    try check(
      stage,
      measured,
      momentTolerance: Self.momentTolerance,
      sourceLocation: sourceLocation,
    )
  }

  func check(
    _ stage: String,
    _ measured: ParityStatistics,
    momentTolerance: Double,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) throws {
    try check(
      stage,
      measured,
      momentTolerance: momentTolerance,
      extremeTolerance: Self.extremeTolerance,
      sourceLocation: sourceLocation,
    )
  }

  func check(
    _ stage: String,
    _ measured: ParityStatistics,
    momentTolerance: Double,
    extremeTolerance: Double,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) throws {
    guard case let .statistics(expected)? = stages[stage] else {
      Issue.record("no \(stage) statistics in the reference", sourceLocation: sourceLocation)
      return
    }
    #expect(
      abs(measured.mean - expected.mean) < momentTolerance,
      "\(stage) mean \(measured.mean) against \(expected.mean)",
      sourceLocation: sourceLocation,
    )
    #expect(
      abs(measured.standardDeviation - expected.standardDeviation) < momentTolerance,
      "\(stage) std \(measured.standardDeviation) against \(expected.standardDeviation)",
      sourceLocation: sourceLocation,
    )
    #expect(
      abs(measured.minimum - expected.minimum) < extremeTolerance,
      "\(stage) min \(measured.minimum) against \(expected.minimum)",
      sourceLocation: sourceLocation,
    )
    #expect(
      abs(measured.maximum - expected.maximum) < extremeTolerance,
      "\(stage) max \(measured.maximum) against \(expected.maximum)",
      sourceLocation: sourceLocation,
    )
  }

  func checkModelScalar(
    _ stage: String,
    _ measured: Double,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) throws {
    let expected = try scalar(stage)
    #expect(
      abs(measured - expected) < Self.modelRelativeTolerance * abs(expected),
      "\(stage) \(measured) against \(expected)",
      sourceLocation: sourceLocation,
    )
  }

  func scalar(_ stage: String) throws -> Double {
    var value: Double?
    if case let .scalar(number)? = stages[stage] {
      value = number
    }
    return try #require(value, "no \(stage) value in the reference")
  }

  func checkModelMean(
    _ stage: String,
    _ measured: ParityStatistics,
    sourceLocation: SourceLocation = #_sourceLocation,
  ) {
    guard case let .statistics(expected)? = stages[stage] else {
      Issue.record("no \(stage) statistics in the reference", sourceLocation: sourceLocation)
      return
    }
    let tolerance = max(
      Self.modelMeanAbsoluteTolerance,
      Self.modelRelativeTolerance * abs(expected.mean),
    )
    #expect(
      abs(measured.mean - expected.mean) < tolerance,
      "\(stage) mean \(measured.mean) against \(expected.mean)",
      sourceLocation: sourceLocation,
    )
  }
}

struct ParityStatistics: Decodable {
  var mean: Double
  var standardDeviation: Double
  var minimum: Double
  var maximum: Double

  enum CodingKeys: String, CodingKey {
    case mean
    case standardDeviation = "std"
    case minimum = "min"
    case maximum = "max"
  }

  init(_ values: [Float]) {
    var sum = 0.0
    var sumOfSquares = 0.0
    var minimum = Double.greatestFiniteMagnitude
    var maximum = -Double.greatestFiniteMagnitude
    for value in values {
      let value = Double(value)
      sum += value
      sumOfSquares += value * value
      minimum = Swift.min(minimum, value)
      maximum = Swift.max(maximum, value)
    }
    let count = Double(values.count)
    mean = sum / count
    standardDeviation = (sumOfSquares / count - mean * mean).squareRoot()
    self.minimum = minimum
    self.maximum = maximum
  }

  init(bytes: [UInt8]) {
    self.init(bytes.map(Float.init))
  }
}
