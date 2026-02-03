//
//  AppGraph.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16.2.25..
//

import Foundation
import UIKit

import VGSL

@MainActor
final class AppGraph {
  let mapStore: MapViewModel.Store
  let appStore: AppModel.Store
  let mapAdapter: MapAdapter
  let urlOpener: UrlOpener

  var orientationLock: Property<OrientationLock?>?

  private let disposePool = AutodisposePool()
  private let favoritesStorage: FavoritesStorage

  init() {
    let requestPerformer = RequestPerformer(
      urlRequestPerformer: URLSession.shared.data
    )
    let imageLoader = ImageLoader(requestPerformer: requestPerformer)
    let storage: KeyValueStorage = UserDefaults.standard
    let favoritesStorage = FavoritesStorage(
      storage: storage,
      makeLoadableImage: imageLoader.makeImage
    )
    let favoritesModel = makeFavoritesModel(
      storage: favoritesStorage.property
    )
    let locationModel = makeLocationModel()
    let remotes = RewindRemotes(
      requestPerformer: requestPerformer,
      imageLoader: imageLoader
    )
    let settings = makeSettings(storage: storage)
    let mapAdapter = MapAdapter(
      showYearColorInClusters: settings.asObservableVariable().showYearColorInClusters
    )
    weak var mapModelRef: MapModel?
    weak var appModelRef: AppModel?
    weak var weakSelf: AppGraph?
    let urlOpener: UrlOpener = { $0.map { UIApplication.shared.open($0) } }
    self.urlOpener = urlOpener
    let mapModel = makeMapModel(
      mapAdapter: mapAdapter,
      annotationsRemote: remotes.annotations,
      applyMapType: { mapAdapter.apply(mapType: $0) },
      performAppAction: { appModelRef?($0) },
      locationModel: locationModel,
      urlOpener: urlOpener,
      settings: settings.asVariable(),
      appState: Variable { appModelRef?.state },
      annotationStore: AnnotationStore(),
      sorting: settings.asVariable().map(\.sorting)
    )
    mapModelRef = mapModel
    mapStore = mapModel.viewStore.bimap(
      state: { $0 },
      action: { .external(.ui($0)) }
    )
    let imageDetailsFactory = { image, source in
      makeImageDetailsModel(
        modelImage: image,
        remote: remotes.imageDetails,
        openSource: source,
        favoritesModel: favoritesModel,
        showOnMap: { coordinate in
          appModelRef?(.imageList(.dismiss))
          appModelRef?(.imageDetails(.dismiss))
          mapModelRef?(.external(.focusOn(coordinate, zoom: 17)))
        },
        canOpenURL: { UIApplication.shared.canOpenURL($0) },
        urlOpener: urlOpener,
        setOrientationLock: { weakSelf?.orientationLock?.value = $0 },
        streetViewAvailability: remotes.streetViewAvailability,
        extractModelImage: { [imageLoader] details in
          Model.Image(details, image: imageLoader.makeImage(path: details.file))
        }
      )
    }
    let searchModelFactory = {
      makeSearchModel(onLocationFound: { location in
        appModelRef?(.search(.dismiss))
        mapModelRef?(.external(.focusOn(location.coordinate, zoom: 15)))
      })
    }
    let onboardingViewModel = makeOnboardingViewModel(
      keyValueStorage: storage,
      onFinish: {
        mapModelRef?(.external(.ui(.mapViewLoaded))) // 🩼
        appModelRef?(.onboarding(.dismiss))
      }
    )
    let appModel = makeAppModel(
      imageDetailsFactory: imageDetailsFactory,
      searchModelFactory: searchModelFactory,
      settingsViewModelFactory: {
        makeSettingsViewModel(
          settings: settings,
          urlOpener: urlOpener
        )
      },
      performMapAction: { mapModelRef?(.external($0)) },
      favoritesModel: favoritesModel,
      onboardingViewModel: onboardingViewModel,
      currentRegionImages: Variable { mapModelRef?.state.currentRegionImages ?? [] },
      sorting: settings.asProperty().bimap(get: \.sorting, modify: { $0.sorting = $1 })
    )
    appModelRef = appModel
    appStore = appModel.viewStore
    self.mapAdapter = mapAdapter
    self.favoritesStorage = favoritesStorage
    weakSelf = self

    mapAdapter.events.addObserver {
      mapModelRef?(.external(.map($0)))
    }.dispose(in: disposePool)
    locationModel.$state.currentAndNewValues.addObserver {
      mapModelRef?(.external(.newLocationState($0)))
    }.dispose(in: disposePool)
    settings.asObservableVariable().map(\.sorting).onChange { _ in
      mapModelRef?(.internal(.updatePreviews))
    }.dispose(in: disposePool)
  }
}
