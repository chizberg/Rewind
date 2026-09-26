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
}

enum FullscreenPreviewAction {
  enum UI {
    case saveImage
  }

  enum Internal {
    case imageSaved
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
          } catch {}
        }))
      }
    case let .internal(`internal`):
      switch `internal` {
      case .imageSaved:
        state.savesCount += 1
      }
    }
  }
  return model.viewStore.bimap(
    state: { $0 },
    action: { .ui($0) }
  )
}
