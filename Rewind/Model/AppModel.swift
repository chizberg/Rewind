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
  var settingsModel: Identified<SettingsModel>?
  var alertModel: Identified<AlertModel>?
}

enum AppAction {
  enum ImageDetails {
    case present(Model.Image, source: String)
    case dismiss
  }

  enum ImageList {
    case presentFavorites(source: String)
    case present([Model.Image], source: String, title: LocalizedStringKey)
    case dismiss
  }

  enum Settings {
    case present
    case dismiss
  }

  enum Alert {
    case present(AlertModel)
    case dismiss
  }

  case imageDetails(ImageDetails)
  case imageList(ImageList)
  case settings(Settings)
  case alert(Alert)
}

typealias UrlOpener = (URL?) -> Void
typealias ImageDetailsFactory = (Model.Image, String) -> ImageDetailsModel

func makeAppModel(
  imageDetailsFactory: @escaping ImageDetailsFactory,
  performMapAction: @escaping (MapAction.External) -> Void,
  favoritesModel: FavoritesModel,
  urlOpener: @escaping UrlOpener
) -> AppModel {
  AppModel(
    initial: AppState(
      previewedImage: nil,
      previewedList: nil,
      settingsModel: nil
    ),
    reduce: { state, action, _ in
      switch action {
      case let .imageDetails(detailsAction):
        switch detailsAction {
        case let .present(image, source):
          state.previewedImage = Identified(
            value: imageDetailsFactory(image, source)
          )
        case .dismiss:
          state.previewedImage = nil
          performMapAction(.previewClosed)
        }
      case let .imageList(listAction):
        switch listAction {
        case let .presentFavorites(source):
          state.previewedList = Identified(
            value: makeImageListModel(
              title: "Favorites",
              matchedTransitionSourceName: source,
              images: favoritesModel.state,
              listUpdates: favoritesModel.$state.newValues,
              imageDetailsFactory: imageDetailsFactory
            )
          )
        case let .present(images, source, title):
          state.previewedList = Identified(
            value: makeImageListModel(
              title: title,
              matchedTransitionSourceName: source,
              images: images,
              listUpdates: .empty,
              imageDetailsFactory: imageDetailsFactory
            )
          )
        case .dismiss:
          state.previewedList = nil
          performMapAction(.previewClosed)
        }
      case let .settings(settingsAction):
        switch settingsAction {
        case .present:
          state.settingsModel = Identified(value:
            makeSettingsModel(urlOpener: urlOpener)
          )
        case .dismiss:
          state.settingsModel = nil
        }
      case let .alert(alertAction):
        switch alertAction {
        case let .present(alertModel):
          state.alertModel = Identified(value: alertModel)
        case .dismiss:
          state.alertModel = nil
        }
      }
    }
  )
}
