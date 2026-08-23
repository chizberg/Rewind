//
//  ColorizationModelStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import Foundation

actor ColorizationModelStore {
  enum ModelKind: String, Codable {
    case ddColorLarge = "ddcolor-large"
    case eccv16
  }

  func localModel(kind: ModelKind) -> ColorizationModel? {
    guard let url = localModelURL(kind) else { return nil }
    print("chzbrg TODO: read the compiled model at \(url)")
    return nil
  }

  private func localModelURL(_ kind: ModelKind) -> URL? {
    let url = modelsDirectory.appending(path: "\(kind.rawValue).mlmodelc")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}

private let modelsDirectory = URL.applicationSupportDirectory
  .appending(path: "ColorizationModels")
