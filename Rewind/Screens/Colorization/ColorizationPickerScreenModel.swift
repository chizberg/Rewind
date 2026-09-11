//
//  ColorizationPickerScreenModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 8. 2026..
//

import SwiftUI
import VGSLFundamentals

enum ColorizationFileAction {
  enum UI {
    case download
    case cancelDownload
    case delete
  }

  enum Internal {
    case observeDownload
    case downloadProgressChanged(CGFloat)
    case installationStarted
    case downloadFinished
    case failed(Error)
  }

  case ui(UI)
  case `internal`(Internal)
}

struct ColorizationPickerScreenState {
  struct Common {
    var picked: ColorizationModelID?
    var sizes: [ColorizationModelID: String]?
    var alert: Identified<AlertParams>?
  }

  var fileStates: [ColorizationModelID: ColorizationFileState]
  var common: Common

  var modelIDs: [ColorizationModelID]
  var colorize: (() -> Void)?
}

enum ColorizationPickerScreenAction {
  struct File {
    var id: ColorizationModelID
    var action: ColorizationFileAction
  }

  enum Common {
    case pick(ColorizationModelID?)
    case loadManifest
    case manifestLoaded(ColorizationManifest)
    case manifestFailed(Error)
    case dismissAlert
  }

  case file(File)
  case common(Common)
}

typealias ColorizationFileModel = Reducer<ColorizationFileState, ColorizationFileAction>
typealias ColorizationPickerScreenStore = ViewStore<
  ColorizationPickerScreenState,
  ColorizationPickerScreenAction
>

@MainActor
func makeColorizationPickerScreenStore(
  modelStore: ColorizationModelStore,
  pickedModel: Property<ColorizationModelID?>,
  manifest: Remote<Void, ColorizationManifest>,
  colorize: (() -> Void)?,
) -> ColorizationPickerScreenStore {
  let common = Reducer<
    ColorizationPickerScreenState.Common,
    ColorizationPickerScreenAction.Common
  >(
    initial: ColorizationPickerScreenState.Common(picked: pickedModel.value),
    reduce: { state, action, _, asyncEffect in
      switch action {
      case let .pick(id):
        state.picked = id
        asyncEffect(.perform { _ in
          pickedModel.value = id
        })
      case .loadManifest:
        asyncEffect(.perform { anotherAction in
          do {
            let loaded = try await manifest.load()
            await anotherAction(.manifestLoaded(loaded))
          } catch {
            await anotherAction(.manifestFailed(error))
          }
        })
      case let .manifestLoaded(manifest):
        var sizes = [ColorizationModelID: String]()
        for id in ColorizationModelID.allCases {
          if let entry = try? manifest.entry(for: id) {
            sizes[id] = entry.bytes.formatted(.byteCount(style: .file))
          }
        }
        state.sizes = sizes
      case let .manifestFailed(error):
        state.alert = Identified(value: .error(
          title: "Unable to load the model list",
          error: error,
        ))
      case .dismissAlert:
        state.alert = nil
      }
    }
  )
  common(.loadManifest)

  let modelIDs = ColorizationModelID.allCases
  var fileStores = [ColorizationModelID: ColorizationFileModel.Store]()
  for id in modelIDs {
    fileStores[id] = makeColorizationFileModel(
      id: id,
      store: modelStore,
      pickedModel: Property(getter: { common.state.picked }, setter: { common(.pick($0)) })
    ).viewStore
  }

  let filesMerged: ViewStore<
    [ColorizationModelID: ColorizationFileState],
    ColorizationPickerScreenAction.File
  > = ViewStore.merge(fileStores, actionTransform: { ($0.id, $0.action) })

  return ViewStore.merge(
    common.viewStore,
    filesMerged,
    stateTransform: { c, fm in
      ColorizationPickerScreenState(
        fileStates: fm,
        common: c,
        modelIDs: modelIDs,
        colorize: colorize,
      )
    },
    actionTransform: { mergedAction in
      switch mergedAction {
      case let .common(c): .left(c)
      case let .file(f): .right(f)
      }
    }
  )
}

@MainActor
private func makeColorizationFileModel(
  id: ColorizationModelID,
  store: ColorizationModelStore,
  pickedModel: Property<ColorizationModelID?>,
) -> ColorizationFileModel {
  let model = ColorizationFileModel(
    initial: store.fileState(id: id),
  ) { state, action, _, asyncEffect in
    switch action {
    case let .ui(ui):
      switch ui {
      case .download:
        assert(state == .available)
        state = .downloading(0)
        asyncEffect(.anotherAction(.internal(.observeDownload)))
      case .cancelDownload:
        assert(state.isDownloading)
        state = .available
        asyncEffect(.cancel(id: downloadEffectID))
      case .delete:
        assert(state == .downloaded)
        do {
          try store.deleteFile(id: id)
          state = .available
          if pickedModel.value == id {
            pickedModel.value = nil
          }
        } catch {
          asyncEffect(.anotherAction(.internal(.failed(error))))
        }
      }
    case let .internal(`internal`):
      switch `internal` {
      case .observeDownload:
        guard state.isInProgress else { return }
        asyncEffect(.perform(id: downloadEffectID) { anotherAction in
          for await jobState in store.download(id: id).states {
            switch jobState {
            case let .running(.downloading(progress)):
              await anotherAction(.internal(.downloadProgressChanged(progress)))
            case .running(.processingFile):
              await anotherAction(.internal(.installationStarted))
            case .finished(.success):
              await anotherAction(.internal(.downloadFinished))
            case let .finished(.failure(error)):
              await anotherAction(.internal(.failed(error)))
            }
          }
        })
      case let .downloadProgressChanged(progress):
        guard state.isDownloading else { return }
        state = .downloading(progress)
      case .installationStarted:
        guard state.isDownloading else { return }
        state = .installing
      case .downloadFinished:
        state = .downloaded
        if pickedModel.value == nil {
          asyncEffect(.perform { _ in
            pickedModel.value = id
          })
        }
      case .failed:
        state = store.fileState(id: id)
      }
    }
  }
  if model.state.isInProgress {
    model(.internal(.observeDownload))
  }
  return model
}

private let downloadEffectID = "download"
