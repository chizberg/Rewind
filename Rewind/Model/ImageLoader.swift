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
  ) -> LoadableImage {
    LoadableImage { [weak self] quality in
      guard let self else { throw IsDead() }
      return try await load(path: path, quality: quality)
    }
  }

  private func load(path: String, quality: ImageQuality) async throws -> UIImage {
    if let image = cached(path: path, quality: quality) {
      return image
    }
    let image = try await fetch(path: path, quality: quality)
    let key = ImageCacheKey(path: path, quality: quality)
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

  private struct IsDead: Error {}
}

private class ImageCacheKey: AnyObject {
  let path: String
  let quality: ImageQuality

  init(path: String, quality: ImageQuality) {
    self.path = path
    self.quality = quality
  }
}

typealias LoadableImage = Remote<ImageQuality, UIImage>

extension LoadableImage {
  func load(
    quality: ImageQuality,
    completion: @escaping @MainActor (UIImage) -> Void
  ) -> Task<Void, Never> {
    self(quality) { result in
      switch result {
      case let .success(image): completion(image)
      case .failure: break // TODO: error handling
      }
    }
  }
}

extension LoadableImage {
  static let mock = LoadableImage { _ in
    UIImage(named: "cat")!
  }
}
