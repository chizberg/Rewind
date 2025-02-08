//
//  ImageDetails.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 14.01.2023.
//

import Foundation

extension Network {
  struct ImageDetails: Decodable {
    let cid: Int // unique image id
    let file: String // local path to image
    let title: String
    let dir: String? // direction
    let geo: [Double] // location, has two values: latitude and longitude
    let year: Int // lower time boundary
    let year2: Int // upper time boundary

    let desc: String? // description of image
    let source: String? // can contain url
    let address: String?
    let author: String?

    let watersignText: String?

    // inner JSON values
    let user: User // user that uploaded the image
  }

  struct User: Decodable {
    let name: String

    enum CodingKeys: String, CodingKey {
      case name = "disp"
    }
  }
}


#if DEBUG
extension Network.ImageDetails {
  static let mock = Network.ImageDetails(
    cid: 1_641_494,
    file: "v/s/s/vssv956fa6kpunaqmm.jpg",
    title: "Теразије",
    dir: "nw",
    geo: [44.813047, 20.460579],
    year: 1958,
    year2: 1965,
    desc: "На самом деле описания в API нет, но его добавлю я.",
    source: "too long for me",
    address: nil,
    author: "Jerry Cooke",
    watersignText: "uploaded by Zanuda Kartotechnaya",
    user: .init(name: "Николай")
  )
}
#endif
