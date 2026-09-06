//
//  ColorizationModelStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import Foundation
import VGSL

final class ColorizationModelStore {
  private let downloadPerformer: DownloadPerformer
  private let manifest: Remote<Void, ColorizationManifest>

  init(
    downloadPerformer: DownloadPerformer,
    manifest: Remote<Void, ColorizationManifest>,
  ) {
    self.downloadPerformer = downloadPerformer
    self.manifest = manifest
  }

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

  @MainActor
  func download(id: ColorizationModelID) -> Job<CGFloat, Void> {
    let connection = ObservableVariableConnection<Job<CGFloat, Void>.State>(
      initialValue: .running(0)
    )
    let task = Task {
      do {
        let entry = try await manifest.load().entry(for: id)
        let transfer = downloadPerformer.perform(.colorizationModel(entry))
        connection.current = ObservableVariable(
          initialValue: connection.value,
          newValues: transfer.state.newValues.compactMap { transferState in
            if case let .running(progress) = transferState { .running(progress) } else { nil }
          },
        )
        let compiled = try await transfer.value
        try place(compiled: compiled, id: id)
        connection.current = .constant(.finished(.success(())))
      } catch {
        connection.current = .constant(.finished(.failure(error)))
      }
    }
    return Job(state: connection.target, cancel: task.cancel)
  }

  private func place(compiled: URL, id: ColorizationModelID) throws {
    var directory = modelsDirectory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
    try FileManager.default.moveItem(at: compiled, to: modelURL(id))
  }

  private func localModelURL(_ id: ColorizationModelID) -> URL? {
    let url = modelURL(id)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  private func modelURL(_ id: ColorizationModelID) -> URL {
    modelsDirectory.appending(path: "\(id.rawValue).mlmodelc")
  }
}

private let modelsDirectory = URL.applicationSupportDirectory
  .appending(path: "ColorizationModels")
