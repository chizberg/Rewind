//
//  AnnotationUpdater.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

struct AnnotationLoader {
  private let requestPerformer: RequestPerformer
  private let imageLoader: ImageLoader

  init(
    requestPerformer: RequestPerformer,
    imageLoader: ImageLoader
  ) {
    self.requestPerformer = requestPerformer
    self.imageLoader = imageLoader
  }

  func loadNewAnnotations(
    region: Region,
    yearRange: ClosedRange<Int>,
    apply: @MainActor @escaping ([Model.Image], [Model.Cluster]) -> Void
  ) {
    Task {
      do {
        let (nis, ncs) = try await load(region: region, yearRange: yearRange)
        let images = nis.map {
          let loadableImage = imageLoader.makeImage(path: $0.file)
          return Model.Image($0, image: loadableImage)
        }
        let clusters = ncs.map {
          let loadableImage = imageLoader.makeImage(path: $0.preview.file)
          return Model.Cluster(nc: $0, image: loadableImage)
        }
        await apply(images, clusters)
      } catch {
        // TODO: error handling
      }
    }
  }

  private func load(
    region: Region,
    yearRange: ClosedRange<Int>
  ) async throws -> ([Network.Image], [Network.Cluster]) {
    try await requestPerformer.perform(
      request: .byBounds(
        zoom: region.zoom,
        coordinates: region.geoJSONCoordinates,
        startAt: Date().timeIntervalSince1970,
        yearRange: yearRange
      )
    )
  }
}
