//
//  ImageDetailsModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation

typealias ImageDetailsModel = Reducer<ImageDetailsState, ImageDetailsAction>

struct ImageDetailsState {
  var data: Model.ImageDetails?
}

enum ImageDetailsAction {
  case willBePresented
  case loaded(Model.ImageDetails)

  case openInWeb
  case addToFavorites
  case saveImage
  case share
}

func makeImageDetailsModel(
  load: Remote<Void, Model.ImageDetails>
) -> ImageDetailsModel {
  Reducer(
    initial: ImageDetailsState(data: nil),
    reduce: { state, action, effect, loadEffect in
      switch action {
      case .willBePresented:
        loadEffect {
          try await .loaded(load())
        }
      case let .loaded(data):
        state.data = data
      case .openInWeb: print("chzbrg open in web")
      case .addToFavorites: print("chzbrg add to favorites")
      case .saveImage: print("chzbrg save image")
      case .share: print("chzbrg share")
      }
    }
  )
}
