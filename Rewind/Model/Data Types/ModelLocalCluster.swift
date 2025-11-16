//
//  ModelLocalCluster.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 11. 2025..
//

import Foundation

extension Model {
  // when multiple annotations are nearby, they are merged into a local cluster
  // don't mix it with Model.Cluster, that thing is for clusters loaded from API
  struct LocalCluster: Equatable {
    var images: [Model.Image]
    var coordinate: Coordinate
    var id = UUID()

    static func ==(lhs: Model.LocalCluster, rhs: Model.LocalCluster) -> Bool {
      lhs.id == rhs.id
    }
  }
}
