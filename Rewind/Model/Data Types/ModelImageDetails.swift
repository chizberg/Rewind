//
//  ModelImageDetails.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation

extension Model {
  struct ImageDetails {
    var cid: Int
    var image: LoadableImage
    var title: String
    var dir: Direction?
    var coordinate: Coordinate
    var date: ImageDate

    var description: String?
    var source: String? // TODO: implement url sources
    var address: String?
    var author: String?

    var username: String

    init(_ ni: Network.ImageDetails, image: LoadableImage) {
      cid = ni.cid
      title = ni.title
      dir = Direction(ni.dir)
      coordinate = Coordinate(ni.geo)
      date = ImageDate(year: ni.year, year2: ni.year2)
      description = ni.desc
      source = ni.source
      address = ni.address
      author = ni.author
      username = extractUsername(from: ni)
      self.image = image
    }
  }
}

private func extractUsername(from nid: Network.ImageDetails) -> String {
  if let watersign = nid.watersignText,
     watersign.hasPrefix(watersignPrefix) {
    return String(watersign.dropFirst(watersignPrefix.count))
  }
  return nid.user.name
}
private let watersignPrefix = "uploaded by "
