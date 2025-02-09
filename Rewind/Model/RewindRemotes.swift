//
//  RewindRemotes.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation

struct RewindRemotes {
  var annotations: Remote<(Region, ClosedRange<Int>), ([Model.Image], [Model.Cluster])>
  var imageDetails: Remote<Int, Model.ImageDetails>
}

extension RewindRemotes {
  init(
    requestPerformer: RequestPerformer,
    imageLoader: ImageLoader
  ) {
    annotations = Remote { region, yearRange in
      let (nis, ncs) = try await requestPerformer.perform(
        request: .byBounds(
          zoom: region.zoom,
          coordinates: region.geoJSONCoordinates,
          startAt: Date().timeIntervalSince1970,
          yearRange: yearRange
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
    }
    imageDetails = Remote { cid in
      let details = try await requestPerformer.perform(request: .imageDetails(cid: cid))
      return Model.ImageDetails(details)
    }
  }
}
