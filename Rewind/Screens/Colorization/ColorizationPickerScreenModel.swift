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
    case downloadFinished
    case failed(Error)
  }

  case ui(UI)
  case `internal`(Internal)
}

struct ColorizationPickerScreenState {
  struct Common {
    var picked: ColorizationModelID?
  }

  var fileStates: [ColorizationModelID: ColorizationFileState]
  var common: Common
}

enum ColorizationPickerScreenAction {
  struct File {
    var id: ColorizationModelID
    var action: ColorizationFileAction
  }

  enum Common {
    case pick(ColorizationModelID?)
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
private func makeColorizationPickerScreenStore(
  modelStore: ColorizationModelStore,
  pickedModel: Property<ColorizationModelID?>,
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
      }
    }
  )

  var fileStores = [ColorizationModelID: ColorizationFileModel.Store]()
  for id in ColorizationModelID.allCases {
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
      ColorizationPickerScreenState(fileStates: fm, common: c)
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
        guard state.isDownloading else { return }
        asyncEffect(.perform(id: downloadEffectID) { anotherAction in
          for await jobState in store.download(id: id).states {
            switch jobState {
            case let .running(progress):
              await anotherAction(.internal(.downloadProgressChanged(progress)))
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
      case .downloadFinished:
        state = .downloaded
      case .failed:
        state = store.fileState(id: id)
      }
    }
  }
  if model.state.isDownloading {
    model(.internal(.observeDownload))
  }
  return model
}

private let downloadEffectID = "download"
