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

extension ColorizationManifest {
  func entry(for id: ColorizationModelID) throws -> Entry {
    guard let entry = models.first(where: { $0.unpackedName == id.packageName }) else {
      throw HandlingError("No \(id.packageName) in the manifest")
    }
    return entry
  }
}

extension ColorizationModelID {
  var packageName: String {
    switch self {
    case .ddColorLarge: "DDColorLarge.mlpackage"
    case .eccv16: "ECCV16.mlpackage"
    }
  }
}

extension ColorizationManifest.Entry {
  var archiveURL: URL {
    colorizationModelSource.appending(path: unpackedName + ".zip")
  }
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
  URL(string: "https://rewind-models.y2nkvndwk7.workers.dev/models/v1")!
