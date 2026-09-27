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
  var settingsStore: Identified<SettingsViewStore>?
  var onboardingStore: Identified<OnboardingViewModel.Store>?
  var searchStore: Identified<SearchViewStore>?
  var alertModel: Identified<AlertParams>?
  var gradientScheme: GradientScheme

  var navigationPath: [Screen]
}

enum AppAction {
  enum ImageDetails {
    case present(Model.Image, source: TransitionSource)
  }

  enum ImageList {
    case presentFavorites(source: TransitionSource)
    case presentCurrentRegionImages(source: TransitionSource)
    case present([Model.Image], source: TransitionSource, title: LocalizedStringKey)
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

  enum Navigation {
    case setPath([Screen])
    case pushScreen(Screen)
  }

  enum Internal {
    case imagePreviewClosed
    case imageListClosed
  }

  case imageDetails(ImageDetails)
  case imageList(ImageList)
  case settings(Settings)
  case onboarding(Onboarding)
  case search(Search)
  case alert(Alert)
  case setGradientScheme(GradientScheme)
  case navigation(Navigation)
  case `internal`(Internal)
}

typealias UrlOpener = (URL?) -> Void
typealias ImageDetailsFactory = (Model.Image, TransitionSource) -> Screen

func makeAppModel(
  imageDetailsFactory: @escaping ImageDetailsFactory,
  searchModelFactory: @escaping () -> SearchModel,
  settingsViewStoreFactory: @escaping () -> SettingsViewStore,
  performMapAction: @escaping (MapAction.External) -> Void,
  favoritesModel: FavoritesModel,
  onboardingViewModel: OnboardingViewModel?,
  currentRegionImages: Variable<[Model.Image]>,
  settings: Property<SettingsState>,
  requestAppStoreReview: @escaping () -> Void,
  pushScreen: @escaping (Screen) -> Void,
) -> AppModel {
  weak var weakSelf: AppModel?
  let openedScreens = Variable {
    weakSelf?.state.navigationPath ?? []
  }
  let model = AppModel(initial: .makeInitial(
    onboardingViewModel: onboardingViewModel,
    settingsState: settings.value,
  )) { state, action, effect, asyncEffect in
    switch action {
    case let .imageDetails(detailsAction):
      switch detailsAction {
      case let .present(image, source):
        state.navigationPath.append(imageDetailsFactory(image, source))
      }
    case let .imageList(listAction):
      switch listAction {
      case let .presentFavorites(source):
        let screen = makeImageListScreen(
          title: "Favorites",
          source: source,
          images: favoritesModel.state.reversed(), // new -> old
          listUpdates: favoritesModel.$state.newValues,
          imageDetailsFactory: imageDetailsFactory,
          sorting: nil,
          pushScreen: pushScreen,
          openedScreens: openedScreens,
        )
        state.navigationPath.append(screen)
      case let .presentCurrentRegionImages(source):
        let screen = makeImageListScreen(
          title: "On the map",
          source: source,
          images: currentRegionImages.value,
          listUpdates: .empty,
          imageDetailsFactory: imageDetailsFactory,
          sorting: settings.sorting,
          pushScreen: pushScreen,
          openedScreens: openedScreens,
        )
        state.navigationPath.append(screen)
      case let .present(images, source, title):
        let screen = makeImageListScreen(
          title: title,
          source: source,
          images: images,
          listUpdates: .empty,
          imageDetailsFactory: imageDetailsFactory,
          sorting: settings.sorting,
          pushScreen: pushScreen,
          openedScreens: openedScreens,
        )
        state.navigationPath.append(screen)
      }
    case let .settings(settingsAction):
      switch settingsAction {
      case .present:
        state.settingsStore = Identified(value: settingsViewStoreFactory())
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
            action: { .external($0) },
          ),
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
    case let .setGradientScheme(gradientScheme):
      state.gradientScheme = gradientScheme
    case let .navigation(navigation):
      switch navigation {
      case let .setPath(path):
        if let lastScreen = state.navigationPath.last,
           path.isEmpty {
          switch lastScreen.kind {
          case .image: asyncEffect(.anotherAction(.internal(.imagePreviewClosed)))
          case .list: asyncEffect(.anotherAction(.internal(.imageListClosed)))
          default: break
          }
        }

        state.navigationPath = path
      case let .pushScreen(screen):
        state.navigationPath.append(screen)
      }
    case let .internal(`internal`):
      switch `internal` {
      case .imagePreviewClosed, .imageListClosed:
        effect {
          performMapAction(.previewClosed)
          requestAppStoreReview()
        }
      }
    }
  }
  weakSelf = model
  return model
}

extension AlertParams {
  static func nonCancelledError(
    title: LocalizedStringResource,
    error: Error,
  ) -> AlertParams? {
    guard !(error is CancellationError) else { return nil }
    return .error(title: title, error: error)
  }

  static func error(
    title: LocalizedStringResource,
    error: Error,
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
          },
        ),
        AlertAction(
          title: "OK",
        ),
      ],
    )
  }

  static func info(
    title: LocalizedStringResource,
    message: LocalizedStringResource,
  ) -> AlertParams {
    AlertParams(
      title: title,
      message: message,
      actions: [
        AlertAction(
          title: "OK",
        ),
      ],
    )
  }
}

extension AppState {
  fileprivate static func makeInitial(
    onboardingViewModel: OnboardingViewModel?,
    settingsState: SettingsState,
  ) -> AppState {
    AppState(
      settingsStore: nil,
      onboardingStore: onboardingViewModel.map {
        Identified(value: $0.viewStore)
      },
      searchStore: nil,
      alertModel: nil,
      gradientScheme: settingsState.gradientScheme,
      navigationPath: [],
    )
  }
}

#if DEBUG
extension AppModel {
  static let mock = AppModel(
    initial: .makeInitial(
      onboardingViewModel: nil,
      settingsState: .default,
    ),
    reduce: { _, _, _, _ in }, // 🩼 - should make a full-working AppModel mock
  )
}
#endif
