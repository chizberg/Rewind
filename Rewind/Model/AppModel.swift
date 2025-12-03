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
  struct MapControlsState {
    var minimization: MinimizationState
  }

  var previewedImage: Identified<ImageDetailsModel.Store>?
  var previewedList: Identified<ImageListModel.Store>?
  var settingsStore: Identified<SettingsViewModel.Store>?
  var onboardingStore: Identified<OnboardingViewModel.Store>?
  var searchStore: Identified<SearchViewStore>?
  var alertModel: Identified<AlertParams>?
  var mapControls: MapControlsState
}

enum AppAction {
  enum ImageDetails {
    case present(Model.Image, source: String)
    case dismiss
  }

  enum ImageList {
    case presentFavorites(source: String)
    case presentCurrentRegionImages(source: String)
    case present([Model.Image], source: String, title: LocalizedStringKey)
    case dismiss
  }

  enum Settings {
    case present
    case dismiss
  }

  enum Onboarding {
    case dismiss
  }

  enum Search {
    case present
    case dismiss
  }

  enum Alert {
    case present(AlertParams?)
    case dismiss
  }

  enum MapControls {
    case setMinimization(MinimizationState)
  }

  case imageDetails(ImageDetails)
  case imageList(ImageList)
  case settings(Settings)
  case onboarding(Onboarding)
  case search(Search)
  case alert(Alert)
  case mapControls(MapControls)
}

typealias UrlOpener = (URL?) -> Void
typealias ImageDetailsFactory = (Model.Image, String) -> ImageDetailsModel

func makeAppModel(
  imageDetailsFactory: @escaping ImageDetailsFactory,
  searchModelFactory: @escaping () -> SearchModel,
  settingsViewModelFactory: @escaping () -> SettingsViewModel,
  performMapAction: @escaping (MapAction.External) -> Void,
  favoritesModel: FavoritesModel,
  onboardingViewModel: OnboardingViewModel?,
  currentRegionImages: Variable<[Model.Image]>
) -> AppModel {
  AppModel(
    initial: .makeInitial(
      onboardingViewModel: onboardingViewModel
    ),
    reduce: { state, action, _ in
      switch action {
      case let .imageDetails(detailsAction):
        switch detailsAction {
        case let .present(image, source):
          state.previewedImage = Identified(
            value: imageDetailsFactory(image, source).viewStore
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
            ).viewStore
          )
        case let .presentCurrentRegionImages(source):
          state.previewedList = Identified(
            value: makeImageListModel(
              title: "On the map",
              matchedTransitionSourceName: source,
              images: currentRegionImages.value,
              listUpdates: .empty,
              imageDetailsFactory: imageDetailsFactory
            ).viewStore
          )
        case let .present(images, source, title):
          state.previewedList = Identified(
            value: makeImageListModel(
              title: title,
              matchedTransitionSourceName: source,
              images: images,
              listUpdates: .empty,
              imageDetailsFactory: imageDetailsFactory
            ).viewStore
          )
        case .dismiss:
          state.previewedList = nil
          performMapAction(.previewClosed)
        }
      case let .settings(settingsAction):
        switch settingsAction {
        case .present:
          state.settingsStore = Identified(value:
            settingsViewModelFactory().viewStore
          )
        case .dismiss:
          state.settingsStore = nil
        }
      case let .onboarding(onboardingAction):
        switch onboardingAction {
        case .dismiss:
          state.onboardingStore = nil
        }
      case let .search(searchAction):
        switch searchAction {
        case .present:
          state.searchStore = Identified(
            value: searchModelFactory().viewStore.bimap(
              state: { $0 },
              action: { .external($0) }
            )
          )
        case .dismiss:
          state.searchStore = nil
        }
      case let .alert(alertAction):
        switch alertAction {
        case let .present(alertModel):
          guard let alertModel else { return }
          state.alertModel = Identified(value: alertModel)
        case .dismiss:
          state.alertModel = nil
        }
      case let .mapControls(mapControlsAction):
        switch mapControlsAction {
        case let .setMinimization(minimization):
          state.mapControls.minimization = minimization
        }
      }
    }
  )
}

extension AlertParams {
  static func nonCancelledError(
    title: LocalizedStringResource,
    error: Error
  ) -> AlertParams? {
    guard !(error is CancellationError) else { return nil }
    return .error(title: title, error: error)
  }

  static func error(
    title: LocalizedStringResource,
    error: Error
  ) -> AlertParams {
    let errorDescription = String(describing: error)
    return AlertParams(
      title: title,
      message: LocalizedStringResource(stringLiteral: errorDescription),
      actions: [
        AlertAction(
          title: "Copy to clipboard",
          handler: {
            UIPasteboard.general.string = errorDescription
          }
        ),
        AlertAction(
          title: "OK"
        ),
      ]
    )
  }

  static func info(
    title: LocalizedStringResource,
    message: LocalizedStringResource
  ) -> AlertParams {
    AlertParams(
      title: title,
      message: message,
      actions: [
        AlertAction(
          title: "OK"
        ),
      ]
    )
  }
}

extension AppState {
  fileprivate static func makeInitial(
    onboardingViewModel: OnboardingViewModel?
  ) -> AppState {
    AppState(
      previewedImage: nil,
      previewedList: nil,
      settingsStore: nil,
      onboardingStore: onboardingViewModel.map {
        Identified(value: $0.viewStore)
      },
      searchStore: nil,
      alertModel: nil,
      mapControls: MapControlsState(minimization: .normal)
    )
  }
}

#if DEBUG
extension AppModel {
  static let mock = AppModel(
    initial: .makeInitial(onboardingViewModel: nil),
    reduce: { state, action, _ in
      switch action { // 🩼 - should make a full-working AppModel mock
      case let .mapControls(.setMinimization(minimization)):
        state.mapControls.minimization = minimization
      default: break
      }
    }
  )
}
#endif
