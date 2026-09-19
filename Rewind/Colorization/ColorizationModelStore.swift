//
//  ColorizationModelStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026.
//

import Foundation
import VGSL

@MainActor
final class ColorizationModelStore {
  typealias DownloadJob = Job<DownloadPerformer.Progress, Void>

  private let downloadPerformer: DownloadPerformer
  private let manifest: Remote<Void, ColorizationManifest>
  private var jobs: [ColorizationModelID: DownloadJob] = [:]

  // The model handed out last, kept so the next colorize reuses the graph its actor already
  // loaded; one at a time, because DDColor's weights alone run to hundreds of megabytes.
  // https://developer.apple.com/videos/play/wwdc2023/10049/
  private var loadedModel: (ColorizationModelID, ColorizationModel)?

  init(
    downloadPerformer: DownloadPerformer,
    manifest: Remote<Void, ColorizationManifest>,
  ) {
    self.downloadPerformer = downloadPerformer
    self.manifest = manifest
  }

  func fileState(id: ColorizationModelID) -> ColorizationFileState {
    switch jobs[id]?.state.value {
    case let .running(.downloading(progress))?:
      .downloading(progress)
    case .running(.processingFile)?:
      .installing
    case .finished?, nil:
      localModelURL(id) == nil ? .available : .downloaded
    }
  }

  func deleteFile(id: ColorizationModelID) throws {
    if loadedModel?.0 == id {
      loadedModel = nil
    }
    guard let url = localModelURL(id) else { return }
    try FileManager.default.removeItem(at: url)
  }

  func clearCache() {
    loadedModel = nil
  }

  func localModel(id: ColorizationModelID) -> ColorizationModel? {
    guard let url = localModelURL(id) else { return nil }
    if case let (loadedID, model)? = loadedModel, loadedID == id {
      return model
    }
    let model: ColorizationModel = switch id {
    case .ddColorLarge: DDColorLarge(modelURL: url)
    case .eccv16: ECCV16(modelURL: url)
    }
    loadedModel = (id, model)
    return model
  }

  func download(id: ColorizationModelID) -> DownloadJob {
    if let job = jobs[id] {
      return job
    }
    let connection = ObservableVariableConnection<DownloadJob.State>(
      initialValue: .running(.downloading(0))
    )
    let task = Task {
      defer { jobs[id] = nil }
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
    let job = Job(state: connection.target, cancel: task.cancel)
    jobs[id] = job
    return job
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
