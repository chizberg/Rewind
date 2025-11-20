//
//  ImageLoader.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import Foundation
import UIKit

import VGSL

final class ImageLoader {
  private let cache: NSCache<ImageCacheKey, UIImage>
  private let requestPerformer: RequestPerformer

  init(requestPerformer: RequestPerformer) {
    cache = NSCache()
    self.requestPerformer = requestPerformer
  }

  func makeImage(
    path: String
  ) -> LoadableUIImage {
    LoadableUIImage { [weak self] params in
      guard let self else { throw HandlingError("is dead") }
      return try await load(path: path, params: params)
    }.exponentialBackoff(attemptCount: 2)
  }

  private func load(path: String, params: ImageLoadingParams) async throws -> UIImage {
    if let image = cached(path: path, quality: params.quality) {
      return image
    } else if params.cachedOnly {
      throw HandlingError("no cached image found")
    }
    let image = try await fetch(path: path, quality: params.quality)
    let key = ImageCacheKey(path: path, quality: params.quality)
    cache.setObject(image, forKey: key)
    return image
  }

  private func fetch(path: String, quality: ImageQuality) async throws -> UIImage {
    try await requestPerformer.perform(request: .image(path: path, quality: quality))
  }

  private func cached(path: String, quality: ImageQuality) -> UIImage? {
    let key = ImageCacheKey(path: path, quality: quality)
    return cache.object(forKey: key)
  }
}

private class ImageCacheKey: NSObject {
  let path: String
  let quality: ImageQuality

  init(path: String, quality: ImageQuality) {
    self.path = path
    self.quality = quality
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? ImageCacheKey else { return false }
    return path == other.path && quality == other.quality
  }

  override var hash: Int {
    var hasher = Hasher()
    hasher.combine(path)
    hasher.combine(quality)
    return hasher.finalize()
  }
}

typealias LoadableUIImage = Remote<ImageLoadingParams, UIImage>
struct ImageLoadingParams {
  var quality: ImageQuality
  var cachedOnly: Bool
}

struct ImageLoadingError: Error {
  var err: Error
}

extension LoadableUIImage {
  func load(_ quality: ImageQuality) async throws -> UIImage {
    try await impl(
      ImageLoadingParams(
        quality: quality,
        cachedOnly: false
      )
    )
  }
}

#if DEBUG
extension LoadableUIImage {
  static let mock = LoadableUIImage { _ in .cat }
  static let panorama = LoadableUIImage { _ in .panorama }
}
#endif
