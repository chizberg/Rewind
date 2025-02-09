//
//  ImageDetailsModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation
import UIKit

typealias ImageDetailsModel = Reducer<ImageDetailsState, ImageDetailsAction>

struct ImageDetailsState {
  var data: Model.ImageDetails?
  var image: UIImage?
}

enum ImageDetailsAction {
  case willBePresented
  case dataLoaded(Model.ImageDetails)
  case imageLoaded(UIImage)

  case openInWeb
  case addToFavorites
  case saveImage
  case share
}

func makeImageDetailsModel(
  load: Remote<Void, Model.ImageDetails>,
  image: LoadableImage
) -> ImageDetailsModel {
  Reducer(
    initial: ImageDetailsState(data: nil),
    reduce: { state, action, effect, loadEffect in
      switch action {
      case .willBePresented:
        loadEffect {
          try await .dataLoaded(load())
        }
        loadEffect {
          try await .imageLoaded(image(.high))
        }
      case let .dataLoaded(data):
        state.data = data
      case let .imageLoaded(image):
        state.image = image
      case .openInWeb: print("chzbrg open in web")
      case .addToFavorites: print("chzbrg add to favorites")
      case .saveImage: print("chzbrg save image")
      case .share: print("chzbrg share")
      }
    }
  )
}
