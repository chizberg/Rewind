//
//  RewindRemotes.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation

struct RewindRemotes {
  var annotations: Remote<AnnotationLoadingParams, ([Model.Image], [Model.Cluster])>
  var imageDetails: Remote<Int, Model.ImageDetails>
  var streetViewAvailability: Remote<Coordinate, StreetViewAvailability>
  var translate: Remote<TranslateParams, String>
}

struct AnnotationLoadingParams {
  var zoom: Int
  var coordinates: [[Double]]
  var startAt: TimeInterval
  var yearRange: ClosedRange<Int>

  init(
    region: Region,
    yearRange: ClosedRange<Int>,
    mapSize: CGSize
  ) {
    self.zoom = Rewind.zoom(region: region, mapSize: mapSize)
    self.coordinates = region.geoJSONCoordinates
    self.startAt = Date().timeIntervalSince1970
    self.yearRange = yearRange
  }
}

struct TranslateParams {
  var text: String
  var target: String
}

extension RewindRemotes {
  init(
    requestPerformer: RequestPerformer,
    imageLoader: ImageLoader
  ) {
    annotations = Remote { params in
      let (nis, ncs) = try await requestPerformer.perform(
        request: .byBounds(
          zoom: params.zoom,
          coordinates: params.coordinates,
          startAt: params.startAt,
          yearRange: params.yearRange
        )
      )
      let images = nis.map {
        let loadableImage = imageLoader.makeImage(path: $0.file)
        return Model.Image($0, image: loadableImage)
      }
      let clusters = ncs.map {
        let loadableImage = imageLoader.makeImage(path: $0.preview.file)
        return Model.Cluster(nc: $0, image: loadableImage)
      }
      return (images, clusters)
    }.exponentialBackoff()
    imageDetails = Remote { cid in
      let details = try await requestPerformer.perform(request: .imageDetails(cid: cid))
      return Model.ImageDetails(details)
    }.exponentialBackoff()
    streetViewAvailability = Remote { coordinate in
      try await requestPerformer.perform(request: .streetViewAvailability(coordinate: coordinate))
    }
    translate = Remote { params in
      try await requestPerformer.perform(request: .translate(params: params))
    }
  }
}
