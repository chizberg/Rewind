//
//  AppModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17.2.25.
//

import Foundation
import VGSL

typealias AppModel = Reducer<AppState, AppAction>

struct AppState {
  var previewedImage: Model.Image?
  var previewedList: [Model.Image]?
  var favorites: [Model.Image]
  var favoritesPresented: Bool
}

enum AppAction {
  case addToFavorites(Model.Image)
  case removeFromFavorites(Model.Image)
  case previewImage(Model.Image)
  case imagePreviewClosed
  case previewList([Model.Image])
  case listPreviewClosed
}

func makeAppModel(
  favoritesStorage: Property<[Model.Image]>,
  performMapAction: @escaping (MapAction.External) -> Void
) -> AppModel {
  AppModel(
    initial: AppState(
      previewedImage: nil,
      previewedList: nil,
      favorites: favoritesStorage.value,
      favoritesPresented: false
    ),
    reduce: { state, action, effect, loadEffect in
      switch action {
      case let .addToFavorites(image):
        guard !state.favorites.contains(image) else { return }
        state.favorites.append(image)
        favoritesStorage.value = state.favorites
      case let .removeFromFavorites(image):
        guard let index = state.favorites.firstIndex(of: image) else {
          return
        }
        state.favorites.remove(at: index)
        favoritesStorage.value = state.favorites
      case let .previewImage(image):
        state.previewedImage = image
      case .imagePreviewClosed:
        state.previewedImage = nil
        performMapAction(.previewClosed)
      case let .previewList(images):
        state.previewedList = images
      case .listPreviewClosed:
        state.previewedList = nil
        performMapAction(.previewClosed)
      }
    }
  )
}
