//
//  Annotation.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import MapKit

// MKAnnotation wrapper for value
final class Annotation: NSObject, MKAnnotation {
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
