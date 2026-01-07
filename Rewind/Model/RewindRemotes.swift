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
}

struct AnnotationLoadingParams {
  var region: Region
  var yearRange: ClosedRange<Int>
}

extension RewindRemotes {
  init(
    requestPerformer: RequestPerformer,
    imageLoader: ImageLoader
  ) {
    annotations = Remote { params in
      let (nis, ncs) = try await requestPerformer.perform(
        request: .byBounds(
          zoom: params.region.zoom,
          coordinates: params.region.geoJSONCoordinates,
          startAt: Date().timeIntervalSince1970,
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
  }
}
