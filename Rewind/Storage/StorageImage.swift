//
//  StorageImage.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17.2.25..
//

enum Storage {} // namespace only

extension Storage {
  struct Image: Codable {
    var cid: Int
    var imagePath: String
    var title: String
    var dir: Direction?
    var coordinate: Coordinate
    var date: ImageDate
    
    init(_ mi: Model.Image) {
      cid = mi.cid
      imagePath = mi.imagePath
      title = mi.title
      dir = mi.dir
      coordinate = mi.coordinate
      date = mi.date
    }
  }
}
