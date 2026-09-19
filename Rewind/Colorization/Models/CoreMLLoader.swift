//
//  CoreMLLoader.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 12. 9. 2026.
//

import CoreML
import Foundation

// Loads a colorization model's compiled graph on the first prediction and keeps it for the next
// ones, so the weights are read on the first colorize tap rather than when the model is picked.
struct CoreMLLoader {
  // The .mlmodelc the store compiled and installed in Application Support.
  // https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device
  private let url: URL
  // The processors Core ML may run the graph on.
  // https://developer.apple.com/documentation/coreml/mlcomputeunits
  private let computeUnits: MLComputeUnits
  // Bytes the graph needs to load and run; with less available the load is refused rather than
  // iOS terminating the app for going over its limit.
  private let requiredMemory: Int
  // The graph once loaded; nil until the first prediction.
  private var loaded: MLModel?

  // The Simulator runs the graph on the CPU: its GPU path returns all-zero ab for DDColor.
  // https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator
  init(url: URL, computeUnits: MLComputeUnits, requiredMemory: Int) {
    self.url = url
    #if targetEnvironment(simulator)
    self.computeUnits = .cpuOnly
    #else
    self.computeUnits = computeUnits
    #endif
    self.requiredMemory = requiredMemory
  }

  // The graph, loaded on the first call. Available memory 0 gives nothing to measure (Simulator,
  // not an app) or means the app is already over its limit, where refusing saves nothing.
  // https://developer.apple.com/documentation/os/os_proc_available_memory
  // https://developer.apple.com/documentation/coreml/mlmodel/init(contentsof:configuration:)
  mutating func model() throws -> MLModel {
    if let loaded { return loaded }
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw HandlingError("The colorization model is not on disk any more")
    }
    let available = os_proc_available_memory()
    guard available == 0 || available >= requiredMemory else {
      throw HandlingError(
        "Not enough memory for colorization: \(available / 1_000_000) MB available",
      )
    }
    let configuration = MLModelConfiguration()
    configuration.computeUnits = computeUnits
    let model = try MLModel(contentsOf: url, configuration: configuration)
    loaded = model
    return model
  }
}
