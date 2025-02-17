//
//  ModelImage.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import UIKit

extension Model {
  struct Image {
    var cid: Int
    var image: LoadableImage
    var imagePath: String // used for persistence
    var title: String
    var dir: Direction?
    var coordinate: Coordinate
    var date: ImageDate

    init(_ ni: Network.Image, image: LoadableImage) {
      cid = ni.cid
      imagePath = ni.file
      title = ni.title
      dir = Direction(ni.dir)
      coordinate = Coordinate(ni.geo)
      date = ImageDate(year: ni.year, year2: ni.year2)
      self.image = image
    }

    init(_ si: Storage.Image, image: LoadableImage) {
      cid = si.cid
      imagePath = si.imagePath
      title = si.title
      dir = si.dir
      coordinate = si.coordinate
      date = si.date
      self.image = image
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

extension Model.Image: Identifiable {
  var id: Int { cid }
}

#if DEBUG
extension Model.Image {
  static let mock = Model.Image(
    .mock,
    image: .mock
  )
}
#endif
