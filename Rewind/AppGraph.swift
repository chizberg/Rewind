//
//  AppGraph.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16.2.25..
//

import Foundation
import UIKit

import VGSL

final class AppGraph {
  let mapStore: ViewStore<MapState, MapAction.External.UI>
  let appStore: ViewStore<AppState, AppAction>
  let mapAdapter: MapAdapter

  private let disposePool = AutodisposePool()
  private let favoritesStorage: FavoritesStorage

  init() {
    let mapAdapter = MapAdapter()
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
    weak var mapModelRef: MapModel?
    weak var appModelRef: AppModel?
    let urlOpener: UrlOpener = { $0.map { UIApplication.shared.open($0) } }
    let mapModel = makeMapModel(
      mapAdapter: mapAdapter,
      annotationsRemote: remotes.annotations,
      applyMapType: { mapAdapter.apply(mapType: $0) },
      performAppAction: { appModelRef?($0) },
      locationModel: locationModel,
      urlOpener: urlOpener
    )
    mapModelRef = mapModel
    mapStore = mapModel.viewStore.bimap(
      state: { $0 },
      action: { .external(.ui($0)) }
    )
    let imageDetailsFactory = { image in
      makeImageDetailsModel(
        modelImage: image,
        load: remotes.imageDetails.mapArgs { image.cid },
        image: image.image,
        coordinate: image.coordinate,
        favoriteModel: favoritesModel.isFavorite(image),
        canOpenURL: { UIApplication.shared.canOpenURL($0) },
        urlOpener: urlOpener
      )
    }
    let appModel = makeAppModel(
      imageDetailsFactory: imageDetailsFactory,
      performMapAction: { mapModelRef?(.external($0)) },
      favoritesModel: favoritesModel,
      urlOpener: urlOpener
    )
    appModelRef = appModel
    appStore = appModel.viewStore
    self.mapAdapter = mapAdapter
    self.favoritesStorage = favoritesStorage

    mapAdapter.events.addObserver {
      mapModelRef?(.external(.map($0)))
    }.dispose(in: disposePool)
    locationModel.$state.currentAndNewValues.addObserver {
      mapModelRef?(.external(.newLocationState($0)))
    }.dispose(in: disposePool)
  }
}
