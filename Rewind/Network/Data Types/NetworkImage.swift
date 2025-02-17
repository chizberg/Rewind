//
//  NetworkImage.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 14.01.2023.
//

import Foundation

extension Network {
  struct Image: Decodable {
    let cid: Int // unique image id
    let file: String // local path to image
    let title: String
    let dir: String? // direction
    let geo: [Double] // location, has two values: latitude and longitude
    let year: Int // lower time boundary
    let year2: Int // upper time boundary
  }
}

#if DEBUG
extension Network.Image {
  static let mock = Network.Image(
    cid: 162_858,
    file: "1/x/8/1x8wdafrtqt1z9i56o.jpg",
    title: "Нижегородская губерния. Макарьевский уезд. Село Лысково",
    dir: "nw",
    geo: [56.040054, 45.044866],
    year: 1894,
    year2: 1895
  )
}
#endif
