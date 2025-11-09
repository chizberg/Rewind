//
//  ModelCluster.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

extension Model {
  struct Cluster {
    var preview: Model.Image
    var coordinate: Coordinate
    var count: Int

    init(nc: Network.Cluster, image: LoadableUIImage) {
      preview = Model.Image(nc.preview, image: image)
      coordinate = Coordinate(nc.geo)
      count = nc.count
    }
  }
}

extension Model.Cluster: Hashable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.preview == rhs.preview && lhs.coordinate == rhs.coordinate && lhs.count == rhs.count
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(preview)
    hasher.combine(count)
  }
}
