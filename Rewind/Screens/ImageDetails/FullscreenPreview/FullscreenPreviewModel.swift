//
//  FullscreenPreviewModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 20. 9. 2026..
//

import SwiftUI

struct FullscreenPreviewState {
  var image: UIImage
  var savesCount: Int
  var source: TransitionSource
  var alert: Identified<AlertParams>?
}

enum FullscreenPreviewAction {
  enum UI {
    case saveImage
    case dismissAlert
  }

  enum Internal {
    case imageSaved
    case saveFailed(Error)
  }

  case ui(UI)
  case `internal`(Internal)
}

typealias FullscreenPreviewModel = Reducer<FullscreenPreviewState, FullscreenPreviewAction>
typealias FullscreenPreviewStore = ViewStore<FullscreenPreviewState, FullscreenPreviewAction.UI>

func makeFullscreenPreviewStore(
  image: UIImage,
  savesCount: Int,
  saveImage: @escaping () async throws -> Void,
  source: TransitionSource,
) -> FullscreenPreviewStore {
  let model = FullscreenPreviewModel(
    initial: FullscreenPreviewState(
      image: image,
      savesCount: savesCount,
      source: source,
    )
  ) { state, action, _, asyncEffect in
    switch action {
    case let .ui(ui):
      switch ui {
      case .saveImage:
        asyncEffect(.perform(action: { anotherAction in
          do {
            try await saveImage()
            await anotherAction(.internal(.imageSaved))
          } catch {
            await anotherAction(.internal(.saveFailed(error)))
          }
        }))
      case .dismissAlert:
        state.alert = nil
      }
    case let .internal(`internal`):
      switch `internal` {
      case .imageSaved:
        state.savesCount += 1
      case let .saveFailed(error):
        state.alert = Identified(value: .error(
          title: "Unable to save image",
          error: error,
        ))
      }
    }
  }
  return model.viewStore.bimap(
    state: { $0 },
    action: { .ui($0) }
  )
}
