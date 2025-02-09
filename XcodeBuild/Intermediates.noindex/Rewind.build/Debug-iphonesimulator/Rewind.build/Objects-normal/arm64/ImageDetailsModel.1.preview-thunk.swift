import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/Model/ImageDetailsModel.swift", line: 1)
//
//  ImageDetailsModel.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import Foundation
import UIKit
import VGSL

typealias ImageDetailsModel = Reducer<ImageDetailsState, ImageDetailsAction>

struct ImageDetailsState {
  var data: Model.ImageDetails?
  var image: UIImage?
  var isFavorite: Bool
  var sharedItems: [Any]
}

enum ImageDetailsAction {
  case willBePresented
  case dataLoaded(Model.ImageDetails)
  case imageLoaded(UIImage)

  enum Button {
    case favorite
    case share
    case saveImage
    case viewOnWeb
    case route
  }

  case button(Button)
  case shareSheetDismissed
}

func makeImageDetailsModel(
  load: Remote<Void, Model.ImageDetails>,
  image: LoadableImage,
  isFavorite: Property<Bool> = removeMe,
  urlOpener: @escaping (URL) -> Void
) -> ImageDetailsModel {
  Reducer(
    initial: ImageDetailsState(
      data: nil,
      isFavorite: isFavorite.value,
      sharedItems: []
    ),
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
      case .button(.viewOnWeb):
        guard let data = state.data else { return }
        var components = URLComponents()
        components.scheme = __designTimeString("#32627_0", fallback: "https")
        components.host = __designTimeString("#32627_1", fallback: "pastvu.com")
        components.path = "/\(data.cid)"
        if let url = components.url {
          urlOpener(url)
        }
      case .button(.favorite):
        state.isFavorite.toggle()
        isFavorite.value = state.isFavorite
      case .button(.saveImage): print(__designTimeString("#32627_2", fallback: "chzbrg save image"))
      case .button(.share):
        guard let data = state.data,
              let image = state.image
        else { return }
        state.sharedItems = [
          "\(data.title), \(data.description ?? __designTimeString("#32627_3", fallback: ""))",
          image
        ]
      case .button(.route): print(__designTimeString("#32627_4", fallback: "chzbrg route"))
      case .shareSheetDismissed:
        state.sharedItems = []
      }
    }
  )
}

var removeMe: Property<Bool> = {
  var favorite = false
  return Property(getter: { favorite }, setter: { favorite = $0 })
}()
