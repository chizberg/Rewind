//
//  AppModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17.2.25.
//

import Foundation
import SwiftUI

import VGSL

typealias AppModel = Reducer<AppState, AppAction>

struct AppState {
  var previewedImage: Identified<ImageDetailsModel>?
  var previewedList: Identified<ImageListModel>?
  var settingsPresented: Bool
}

enum AppAction {
  case previewImage(Model.Image)
  case imagePreviewClosed
  case openImageList([Model.Image], source: String)
  case listPreviewClosed
  case settingsButtonTapped
  case favoritesButtonTapped(source: String)
  case settingsClosed
}

func makeAppModel(
  imageDetailsFactory: @escaping (Model.Image) -> ImageDetailsModel,
  performMapAction: @escaping (MapAction.External) -> Void,
  favoritesModel: FavoritesModel
) -> AppModel {
  AppModel(
    initial: AppState(
      previewedImage: nil,
      previewedList: nil,
      settingsPresented: false
    ),
    reduce: { state, action, _ in
      switch action {
      case let .previewImage(image):
        state.previewedImage = Identified(value: imageDetailsFactory(image))
      case .imagePreviewClosed:
        state.previewedImage = nil
        performMapAction(.previewClosed)
      case let .openImageList(images, source):
        state.previewedList = Identified(
          value: makeImageListModel(
            title: "Images",
            matchedTransitionSourceName: source,
            images: images,
            listUpdates: .empty,
            imageDetailsFactory: imageDetailsFactory
          )
        )
      case let .favoritesButtonTapped(source):
        state.previewedList = Identified(
          value: makeImageListModel(
            title: "Favorites",
            matchedTransitionSourceName: source,
            images: favoritesModel.state,
            listUpdates: favoritesModel.$state.newValues,
            imageDetailsFactory: imageDetailsFactory
          )
        )
      case .listPreviewClosed:
        state.previewedList = nil
        performMapAction(.previewClosed)
      case .settingsButtonTapped:
        state.settingsPresented = true
      case .settingsClosed:
        state.settingsPresented = false
      }
    }
  )
}
