//
//  ColorizationParityTests.swift
//  RewindTests
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

@testable import Rewind
import Testing
import UIKit

struct ColorizationParityTests {
  static let frames = ["2209460", "2504212"]
  static let lightnessTolerance = 0.15

  @Test(arguments: frames)
  func grayFrame(_ frame: String) throws {
    let reference = try ParityReference.load()
    let expected = try reference.expected(frame: frame, model: .ddColorLarge)

    let gray = try reference.gray(frame: frame)

    try expected.check("1_to_gray_rgb", ParityStatistics(bytes: gray.values))
  }

  @Test(arguments: frames, ColorizationModelID.allCases)
  func preparedFrame(_ frame: String, _ model: ColorizationModelID) throws {
    let reference = try ParityReference.load()
    let expected = try reference.expected(frame: frame, model: model)

    let input = try ColorizationPipeline.prepare(
      image: reference.input(frame: frame),
      claheClip: expected.claheClip,
    )

    try expected.check("3_clahe_rgb", ParityStatistics(bytes: input.gray.values))
    try expected.check(
      "5_L",
      ParityStatistics(input.lightness.values),
      momentTolerance: Self.lightnessTolerance,
    )
  }
}

struct ParityReference: Decodable {
  enum Stage: Decodable {
    case statistics(ParityStatistics)
    case other

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(ParityStatistics.self) {
        self = .statistics(value)
      } else {
        self = .other
      }
    }
  }

  struct Case: Decodable {
    var claheClip: Double
    var stages: [String: Stage]

    enum CodingKeys: String, CodingKey {
      case claheClip = "clahe"
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
}

extension ParityReference.Case {
  static let momentTolerance = 0.05
  static let extremeTolerance = 1.0

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
      abs(measured.minimum - expected.minimum) < Self.extremeTolerance,
      "\(stage) min \(measured.minimum) against \(expected.minimum)",
      sourceLocation: sourceLocation,
    )
    #expect(
      abs(measured.maximum - expected.maximum) < Self.extremeTolerance,
      "\(stage) max \(measured.maximum) against \(expected.maximum)",
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
