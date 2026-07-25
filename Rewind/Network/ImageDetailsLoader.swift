//
//  ImageDetailsLoader.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 26.07.2026.
//

import Foundation

actor ImageDetailsLoader {
  private var cache: [Int: Model.ImageDetails]
  private let requestPerformer: RequestPerformer

  init(requestPerformer: RequestPerformer) {
    cache = [:]
    self.requestPerformer = requestPerformer
  }

  /// Clears all cached details from memory.
  /// Called automatically on memory warnings.
  func clearCache() {
    cache.removeAll()
  }

  func load(cid: Int) async throws -> Model.ImageDetails {
    if let cached = cache[cid] {
      return cached
    }
    let networkDetails = try await requestPerformer.perform(request: .imageDetails(cid: cid))
    let details = Model.ImageDetails(networkDetails)
    cache[cid] = details
    return details
  }
}
