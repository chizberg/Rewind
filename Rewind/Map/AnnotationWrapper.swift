//
//  Annotation.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import MapKit

final class AnnotationWrapper: NSObject, MKAnnotation {
  enum Value {
    case image(Model.Image)
    case cluster(Model.Cluster)
  }

  var value: Value

  init(value: Value) {
    self.value = value
  }

  var coordinate: Coordinate {
    switch value {
    case let .image(image): image.coordinate
    case let .cluster(cluster): cluster.coordinate
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
}
