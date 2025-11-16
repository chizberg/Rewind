//
//  AnnotationWrapper.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import MapKit

final class AnnotationWrapper: NSObject, MKAnnotation {
  enum Value {
    case cluster(Model.Cluster)
    case image(Model.Image)
    case localCluster(Model.LocalCluster)
  }

  var value: Value

  init(value: Value) {
    self.value = value
  }

  var coordinate: Coordinate {
    switch value {
    case let .cluster(cluster): cluster.coordinate
    case let .image(image): image.coordinate
    case let .localCluster(localCluster): localCluster.coordinate
    }
  }
}

extension AnnotationWrapper.Value {
  var image: Model.Image? {
    if case let .image(image) = self { image } else { nil }
  }

  var cluster: Model.Cluster? {
    if case let .cluster(cluster) = self { cluster } else { nil }
  }

  var localCluster: Model.LocalCluster? {
    if case let .localCluster(localCluster) = self { localCluster } else { nil }
  }
}
