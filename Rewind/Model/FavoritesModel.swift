//
//  FavoritesModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
//

import Foundation
import VGSL

typealias FavoritesModel = Reducer<[Model.Image], FavoritesAction>
typealias SingleFavoriteModel = Reducer<Bool, Bool>

enum FavoritesAction {
  case addToFavorites(Model.Image)
  case removeFromFavorites(Model.Image)
}

func makeFavoritesModel(
  storage: Property<[Model.Image]>
) -> FavoritesModel {
  Reducer(
    initial: storage.value,
    reduce: { state, action, _ in
      switch action {
      case let .addToFavorites(image):
        guard !state.contains(image) else { return }
        state.append(image)
        storage.value = state
      case let .removeFromFavorites(image):
        guard let index = state.firstIndex(of: image) else {
          return
        }
        state.remove(at: index)
        storage.value = state
      }
    }
  )
}

extension FavoritesModel {
  func isFavorite(_ image: Model.Image) -> SingleFavoriteModel {
    unsafeBimap(
      state: { $0.contains { $0.cid == image.cid } },
      action: { $0 ? .addToFavorites(image) : .removeFromFavorites(image) }
    )
  }
}
