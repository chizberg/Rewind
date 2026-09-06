//
//  ColorizationManifest.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import Foundation

struct ColorizationManifest: Decodable {
  struct Entry: Decodable {
    var unpackedName: String
    var bytes: Int64
    var sha256: String
  }

  var models: [Entry]
}

extension Network.Request {
  static func colorizationManifest() -> Network.Request<ColorizationManifest> {
    Network.Request(
      makeURLRequest: {
        URLRequest(url: colorizationModelSource.appending(path: "manifest.json"))
      },
      parseResult: { data in
        try JSONDecoder().decode(ColorizationManifest.self, from: data)
      },
    )
  }
}

private let colorizationModelSource =
  URL(string: "https://rewind-models.y2nkvndwk7.workers.dev/models/test1")!
