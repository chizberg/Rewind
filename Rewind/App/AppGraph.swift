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
  let mapControlsStore: MapControlsStore
  let floatingMenuStore: FloatingMenu.Store
  let rootViewMapStore: RootView.Map.Store
  let appStore: AppModel.Store

  let map: Lazy<RewindMap>
  let urlOpener: UrlOpener
  let imageLoader: ImageLoader

  var orientationLock: Property<OrientationLock?>?

  private let mapModel: MapModel
  private let disposePool = AutodisposePool()
  private let favoritesStorage: FavoritesStorage
  private var memoryWarningObserver: NSObjectProtocol?

  init() {
    let requestPerformer = RequestPerformer(
      urlRequestPerformer: URLSession.shared.data,
    )
    let imageLoader = ImageLoader(requestPerformer: requestPerformer)
    self.imageLoader = imageLoader
    let annotationStore = AnnotationStore()
    let storage: KeyValueStorage = UserDefaults.standard
    let favoritesStorage = FavoritesStorage(
      storage: storage,
      makeLoadableImage: imageLoader.makeImage,
    )
    let favoritesModel = makeFavoritesModel(
      storage: favoritesStorage.property,
    )
    let locationModel = makeLocationModel()
    let remotes = RewindRemotes(
      requestPerformer: requestPerformer,
      imageLoader: imageLoader,
    )
    let settings = makeSettings(storage: storage)

    let filters = ObservableVariableConnection(
      initialValue: ImageRequestFilters.default
    )
    let map = Lazy(onMainThreadGetter: {
      RewindMap(
        settings: settings.asObservableVariable(),
        filters: filters.target
      )
    })

    weak var mapModelRef: MapModel?
    weak var appModelRef: AppModel?
    weak var weakSelf: AppGraph?
    let urlOpener: UrlOpener = { $0.map { UIApplication.shared.open($0) } }
    self.urlOpener = urlOpener
    mapModel = makeMapModel(
      map: map,
      annotationsRemote: remotes.annotations,
      applyMapType: { map.value.apply(mapType: $0) },
      performAppAction: { appModelRef?($0) },
      locationModel: locationModel,
      urlOpener: urlOpener,
      settings: settings.asVariable(),
      annotationStore: annotationStore,
      sorting: settings.asVariable().map(\.sorting),
    )
    mapModelRef = mapModel
    let mapStore = mapModel.viewStore.bimap(
      state: { $0 },
      action: { .external(.ui($0)) },
    )
    mapControlsStore = mapStore.makeControlsStore()
    rootViewMapStore = makeRootMapStore(mapStore: mapStore)
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
        translate: remotes.translate,
        extractModelImage: { [imageLoader] details in
          Model.Image(details, image: imageLoader.makeImage(path: details.file))
        },
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
      },
    )
    let storeReview = AppStoreReview(storage: storage)
    let appModel = makeAppModel(
      imageDetailsFactory: imageDetailsFactory,
      searchModelFactory: searchModelFactory,
      settingsViewModelFactory: {
        makeSettingsViewModel(
          settings: settings,
          urlOpener: urlOpener,
        )
      },
      performMapAction: { mapModelRef?(.external($0)) },
      favoritesModel: favoritesModel,
      onboardingViewModel: onboardingViewModel,
      currentRegionImages: Variable { mapModelRef?.state.currentRegionImages ?? [] },
      settings: settings.asProperty(),
      requestAppStoreReview: { storeReview.request() },
    )
    appModelRef = appModel
    appStore = appModel.viewStore
    floatingMenuStore = makeFloatingMenuStore(
      appStore: appStore,
      mapStore: mapStore
    )
    self.map = map
    self.favoritesStorage = favoritesStorage
    weakSelf = self

    map.future.asSignal().flatMap(\.events).addObserver {
      mapModelRef?(.external(.map($0)))
    }.dispose(in: disposePool)
    locationModel.$state.currentAndNewValues.addObserver {
      mapModelRef?(.external(.newLocationState($0)))
    }.dispose(in: disposePool)
    settings.sorting.asObservableVariable().onChange { _ in
      mapModelRef?(.internal(.updatePreviews))
    }.dispose(in: disposePool)
    settings.gradientScheme.asObservableVariable().onChange {
      appModelRef?(.setGradientScheme($0))
    }.dispose(in: disposePool)
    ObservableVariable.combineLatest(
      mapModel.$state.controls.minimization.skipRepeats(),
      mapModel.$state.controls.size.skipRepeats()
    ).newValues.addObserver { minimization, size in
      let hiddenPart = minimization.isMinimized ? mapControlsMinimizedOffset : 0
      map.value.updateBottomInset(size.height - hiddenPart)
    }.dispose(in: disposePool)
    filters.current = mapModel.$state.filters.skipRepeats()

    // React to memory warnings by clearing image cache
    memoryWarningObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didReceiveMemoryWarningNotification,
      object: nil,
      queue: .main,
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.imageLoader.clearCache()
      }
    }
    storeReview.appLaunched()

    assert(
      map.currentValue == nil,
      "the map is loaded too early, this can result in a runtime crash"
    )
  }

  deinit {
    if let observer = memoryWarningObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}
