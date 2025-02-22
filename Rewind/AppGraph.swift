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
  let mapModel: MapModel
  let appModel: AppModel
  let mapState: ObservedVariable<MapState>
  let appState: ObservedVariable<AppState>
  let mapAdapter: MapAdapter
  let imageDetailsFactory: (Model.Image) -> ImageDetailsModel

  private let disposePool = AutodisposePool()
  private let favoritesStorage: FavoritesStorage
  private let locationProvider: LocationProvider

  init() {
    weak var weakSelf: AppGraph?
    let mapAdapter = MapAdapter()
    let requestPerformer = RequestPerformer(
      urlRequestPerformer: URLSession.shared.data
    )
    let imageLoader = ImageLoader(requestPerformer: requestPerformer)
    let throttler = Throttler()
    let favoritesStorage = FavoritesStorage(
      storage: UserDefaults.standard,
      makeLoadableImage: imageLoader.makeImage
    )
    let locationProvider = LocationProvider()

    let remotes = RewindRemotes(
      requestPerformer: requestPerformer,
      imageLoader: imageLoader
    )
    mapModel = makeMapModel(
      addAnnotations: mapAdapter.add,
      clearAnnotations: mapAdapter.clear,
      deselectAnnotations: mapAdapter.deselectAnnotations,
      visibleAnnotations: Variable { mapAdapter.visibleAnnotations },
      setRegion: mapAdapter.set(region:animated:),
      setCenter: mapAdapter.set(center:animated:),
      annotationsRemote: remotes.annotations,
      applyMapType: { mapAdapter.apply(mapType: $0) },
      performAppAction: { weakSelf?.appModel($0) },
      startLocationUpdating: locationProvider.start,
      throttle: { mapAction in
        // TODO: simplify, no probably no need to pass mapaction itself
        throttler.throttle(mapAction, perform: { weakSelf?.mapModel($0) })
      }
    )
    appModel = makeAppModel(
      favoritesStorage: favoritesStorage.property,
      performMapAction: { weakSelf?.mapModel(.external($0)) }
    )
    imageDetailsFactory = { image in
      makeImageDetailsModel(
        load: remotes.imageDetails.mapArgs { image.cid },
        image: image.image,
        coordinate: image.coordinate,
        isFavorite: weakSelf?.appModel.isFavorite(image) ?? .constant(false),
        canOpenURL: { UIApplication.shared.canOpenURL($0) },
        urlOpener: { UIApplication.shared.open($0) }
      )
    }
    self.mapAdapter = mapAdapter
    self.mapState = mapModel.$state.asObservedVariable()
    self.appState = appModel.$state.asObservedVariable()
    self.favoritesStorage = favoritesStorage
    self.locationProvider = locationProvider
    weakSelf = self

    mapAdapter.events.addObserver { [weak self] in
      self?.mapModel(.external(.map($0)))
    }.dispose(in: disposePool)
    locationProvider.$location.currentAndNewValues.addObserver { [weak self] in
      self?.mapModel(.external(.locationChanged($0)))
    }.dispose(in: disposePool)
  }
}

extension AppModel {
  func isFavorite(_ image: Model.Image) -> Property<Bool> {
    let isFavorite = Variable {
      state.favorites.contains { $0.cid == image.cid }
    }
    return Property(
      getter: { isFavorite.value },
      setter: { newValue in
        switch (isFavorite.value, newValue) {
        case (false, true): self(.addToFavorites(image))
        case (true, false): self(.removeFromFavorites(image))
        case (true, true), (false, false): break
        }
      }
    )
  }
}
