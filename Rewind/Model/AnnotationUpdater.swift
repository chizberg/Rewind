//
//  AnnotationUpdater.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

final actor AnnotationUpdater {
  private let requestPerformer: RequestPerformer
  private var clusters: Set<Model.Cluster>
  private var images: Set<Model.Image>

  init(requestPerformer: RequestPerformer) {
    self.requestPerformer = requestPerformer
    clusters = []
    images = []
  }

//  func loadNewAnnotations(
//    region: Region,
//    yearRange: ClosedRange<Int>
//  ) async -> [Annotation] {
//    let requestPerformer.perform(
//      request: .byBounds(
//        zoom: region.zoom,
//        coordinates: region.geoJSONCoordinates,
//        startAt: Date().timeIntervalSince1970,
//        yearRange: yearRange
//      )
//    )
//  }

  func clear() {
    clusters.removeAll()
    images.removeAll()
  }
}

enum Annotation {
  case cluster(Model.Cluster)
  case image(Model.Image)
}
