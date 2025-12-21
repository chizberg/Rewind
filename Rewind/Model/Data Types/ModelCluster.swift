//
//  ModelCluster.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

import VGSL

extension Model {
  struct Cluster {
    var preview: Model.Image
    var coordinate: Coordinate
    var count: Int

    init(nc: Network.Cluster, image: LoadableUIImage) {
      preview = modified(Model.Image(nc.preview, image: image)) {
        $0.coordinate = $0.coordinate.reversed() // 🩼
      }
      coordinate = Coordinate(nc.geo)
      count = nc.count
    }

    init(preview: Model.Image, coordinate: Coordinate, count: Int) {
      self.preview = preview
      self.coordinate = coordinate
      self.count = count
    }
  }
}

extension Model.Cluster: Hashable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.preview == rhs.preview && lhs.coordinate == rhs.coordinate && lhs.count == rhs.count
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(preview)
    hasher.combine(coordinate)
    hasher.combine(count)
  }
}

extension Coordinate: @retroactive Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(latitude)
    hasher.combine(longitude)
  }
}
