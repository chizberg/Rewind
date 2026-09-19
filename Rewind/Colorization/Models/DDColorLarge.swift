//
//  DDColorLarge.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

import CoreML
import Foundation

// DDColor-large converted to Core ML at fp16: gray frame in, ab out. An actor: a prediction takes
// seconds and the MLModel stays isolated on it.
// https://arxiv.org/abs/2212.11613
actor DDColorLarge: ColorizationModel {
  // Fixed input side the graph was traced for; the reference's working resolution.
  private static let inputSide = 384
  // Input feature name given at conversion.
  private static let inputFeature = "grayRGB"
  // Output feature name given at conversion.
  private static let outputFeature = "ab"
  // Memory gate threshold: above the 435 MB fp16 weights, below torch's 1.7 GB high-water at 384;
  // not measured for Core ML.
  private static let requiredMemory = 1_200_000_000

  // The clip limit the reference measured for DDColor.
  nonisolated let claheClip = 1.0

  // The gain the reference measured for DDColor: left alone, its color is pale.
  nonisolated let boldness: Float = 1.5

  // The graph, loaded on the first prediction.
  private var loader: CoreMLLoader

  // Not the Neural Engine: fp16 ConvNeXt-L there gives mean |delta ab| 8.56.
  // https://developer.apple.com/documentation/coreml/mlcomputeunits/cpuandgpu
  init(modelURL: URL) {
    loader = CoreMLLoader(
      url: modelURL,
      computeUnits: .cpuAndGPU,
      requiredMemory: Self.requiredMemory,
    )
  }

  // ab at the gray frame's size: the frame fitted into the graph's square, reflect-padded for
  // inference, cropped and scaled back after. The reference pads to a multiple of 32, which a
  // fixed-shape graph cannot take.
  func predict(gray: Plane<UInt8>) throws -> ABPlanes {
    let scale = Double(Self.inputSide) / Double(max(gray.size.width, gray.size.height))
    let fitted = PlaneSize(
      width: max(1, Int((Double(gray.size.width) * scale).rounded())),
      height: max(1, Int((Double(gray.size.height) * scale).rounded())),
    )
    let square = PlaneSize(width: Self.inputSide, height: Self.inputSide)
    return try infer(gray.resized(target: fitted).padded(target: square))
      .cropped(target: fitted)
      .bilinearResized(target: gray.size)
  }

  // One prediction through the graph's image input.
  // https://developer.apple.com/documentation/coreml/mlfeaturevalue/init(cgimage:constraint:options:)-30mu4
  private func infer(_ square: Plane<UInt8>) throws -> ABPlanes {
    let model = try loader.model()
    guard let constraint = model.modelDescription
      .inputDescriptionsByName[Self.inputFeature]?.imageConstraint
    else {
      throw HandlingError("The colorization model does not take an image")
    }
    let input = try MLDictionaryFeatureProvider(dictionary: [
      Self.inputFeature: MLFeatureValue(
        cgImage: square.makeCGImage(),
        constraint: constraint,
        options: nil,
      ),
    ])
    let output = try model.prediction(from: input)
    guard let array = output.featureValue(for: Self.outputFeature)?.multiArrayValue else {
      throw HandlingError("The colorization model returned no colors")
    }
    return try ABPlanes(array, size: square.size)
  }
}
