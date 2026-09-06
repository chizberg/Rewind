//
//  ColorizationModelStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import Foundation

final class ColorizationModelStore {
  func fileState(id: ColorizationModelID) -> ColorizationFileState {
    localModelURL(id) == nil ? .available : .downloaded
  }

  func deleteFile(id: ColorizationModelID) throws {
    guard let url = localModelURL(id) else { return }
    try FileManager.default.removeItem(at: url)
  }

  func localModel(id: ColorizationModelID) -> ColorizationModel? {
    guard let url = localModelURL(id) else { return nil }
    print("chzbrg TODO: read the compiled model at \(url)")
    return nil
  }

  private func localModelURL(_ id: ColorizationModelID) -> URL? {
    let url = modelsDirectory.appending(path: "\(id.rawValue).mlmodelc")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}

private let modelsDirectory = URL.applicationSupportDirectory
  .appending(path: "ColorizationModels")
