//
//  ECCV16.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 13. 9. 2026.
//

import CoreML
import Foundation

// ECCV16 (Zhang et al.) converted to Core ML at fp32: lightness in, ab out, with the reference's
// decode of its 313 ab bins inside the graph. An actor: the MLModel stays isolated on it.
// https://arxiv.org/abs/1603.08511
actor ECCV16: ColorizationModel {
  // Fixed input side the graph was converted for; above 256 the model invents colors.
  private static let inputSide = 256
  // Exponent on each bin's chroma in the graph's decode; the plain mean (0) is washed out.
  private static let rebalance: Float = 2
  // Lightness input feature name given at conversion.
  private static let lightnessFeature = "lightness"
  // Rebalance input feature name given at conversion.
  private static let rebalanceFeature = "rebalance"
  // Output feature name given at conversion.
  private static let outputFeature = "ab"
  // Memory gate threshold: the 123 MB fp32 weights plus headroom for activations; not measured
  // for Core ML.
  private static let requiredMemory = 400_000_000

  // The clip limit the reference measured for ECCV16.
  nonisolated let claheClip = 1.5

  // The graph, loaded on the first prediction.
  private var loader: CoreMLLoader

  // Any compute unit: at fp32, CPU, GPU and the Neural Engine all match torch to 0.0006 mean
  // |delta ab|; at fp16 the CPU overflows into NaN.
  // https://developer.apple.com/documentation/coreml/mlcomputeunits/all
  init(modelURL: URL) {
    loader = CoreMLLoader(
      url: modelURL,
      computeUnits: .all,
      requiredMemory: Self.requiredMemory,
    )
  }

  // ab at the gray frame's size: the frame squashed into the graph's square, proportions ignored
  // as the upstream model and the reference run it, the ab scaled back after.
  // https://github.com/richzhang/colorization/blob/master/colorizers/util.py
  func predict(gray: Plane<UInt8>) throws -> ABPlanes {
    let square = PlaneSize(width: Self.inputSide, height: Self.inputSide)
    return try infer(Lab.lightness(ofGray: gray.bicubicResized(target: square)))
      .bilinearResized(target: gray.size)
  }

  // One prediction through the graph's lightness and rebalance inputs.
  // https://developer.apple.com/documentation/coreml/mlfeaturevalue/init(shapedarray:)
  private func infer(_ lightness: Plane<Float>) throws -> ABPlanes {
    let model = try loader.model()
    let input = try MLDictionaryFeatureProvider(dictionary: [
      Self.lightnessFeature: MLFeatureValue(shapedArray: MLShapedArray(
        scalars: lightness.values,
        shape: [1, 1, lightness.size.height, lightness.size.width],
      )),
      Self.rebalanceFeature: MLFeatureValue(
        shapedArray: MLShapedArray(scalars: [Self.rebalance], shape: [1]),
      ),
    ])
    let output = try model.prediction(from: input)
    guard let array = output.featureValue(for: Self.outputFeature)?.multiArrayValue else {
      throw HandlingError("The colorization model returned no colors")
    }
    return try ABPlanes(array, size: lightness.size)
  }
}
