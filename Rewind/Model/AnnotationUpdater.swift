//
//  AnnotationUpdater.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

struct AnnotationLoader {
  private let requestPerformer: RequestPerformer

  init(
    requestPerformer: RequestPerformer
  ) {
    self.requestPerformer = requestPerformer
  }

  func loadNewAnnotations(
    region: Region,
    yearRange: ClosedRange<Int>,
    apply: @MainActor @escaping ([Model.Image], [Model.Cluster]) -> Void
  ) {
    Task {
      do {
        let (images, clusters) = try await load(region: region, yearRange: yearRange)
        await apply(images, clusters)
      } catch {
        // TODO: error handling
      }
    }
  }

  private func load(
    region: Region,
    yearRange: ClosedRange<Int>
  ) async throws -> ([Model.Image], [Model.Cluster]) {
    let (receivedImages, receivedClusters) = try await requestPerformer.perform(
      request: .byBounds(
        zoom: region.zoom,
        coordinates: region.geoJSONCoordinates,
        startAt: Date().timeIntervalSince1970,
        yearRange: yearRange
      )
    )

    return (receivedImages.map(Model.Image.init), receivedClusters.map(Model.Cluster.init))
  }
}
