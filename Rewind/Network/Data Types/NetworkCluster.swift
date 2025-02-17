//
//  NetworkCluster.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 14.01.2023.
//

import Foundation

extension Network {
  struct Cluster: Decodable {
    let preview: Network.Image // preview pic
    let geo: [Double] // location, has two values: latitude and longitude
    let count: Int // contained images count

    enum CodingKeys: String, CodingKey {
      case preview = "p"
      case geo
      case count = "c"
    }
  }
}

#if DEBUG
extension Network.Cluster {
  static let mock = Network.Cluster(
    preview: .mock,
    geo: [56.040054, 45.044866],
    count: 150
  )
}
#endif
