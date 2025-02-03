//
//  ModelImage.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

extension Model {
  struct Image {
    var cid: Int
    var file: String
    var title: String
    var dir: Direction?
    var coordinate: Coordinate
    var date: ImageDate

    init(_ ni: Network.Image) {
      cid = ni.cid
      file = ni.file
      title = ni.title
      dir = Direction(ni.dir)
      coordinate = Coordinate(ni.geo)
      date = ImageDate(year: ni.year, year2: ni.year2)
    }
  }
}

extension Model.Image: Hashable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.cid == rhs.cid
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(cid)
  }
}
