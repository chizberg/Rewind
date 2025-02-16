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
  let mapAdapter: MapAdapter
  let mapState: ObservedVariable<MapState>
  let imageDetailsFactory: (Model.Image) -> ImageDetailsModel
  let uiActionHandler: (MapAction.External.UI) -> Void
  private let disposePool = AutodisposePool()

  init() {
    weak var weakSelf: AppGraph?
    let mapAdapter = MapAdapter()
    let requestPerformer = RequestPerformer(urlRequestPerformer: URLSession.shared.data)
    let imageLoader = ImageLoader(requestPerformer: requestPerformer)
    let throttler = Throttler()

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
      requestAnnotations: { region, yearRange in
        remotes.annotations(
          (region: region, yearRange: yearRange), // TODO
          completion: { result in
            switch result {
            case let .success((images, clusters)):
              weakSelf?.mapModel(.external(.loaded(images, clusters)))
            case .failure: break // TODO
            }
          }
        )
      },
      applyMapType: { mapAdapter.apply(mapType: $0) },
      throttle: { mapAction in
        // TODO: simplify, no probably no need to pass mapaction itself
        throttler.throttle(mapAction, perform: { weakSelf?.mapModel($0) })
      }
    )
    self.mapAdapter = mapAdapter
    self.mapState = mapModel.$state.asObservedVariable()
    imageDetailsFactory = { image in
      makeImageDetailsModel(
        load: remotes.imageDetails.mapArgs { image.cid },
        image: image.image,
        coordinate: image.coordinate,
        canOpenURL: { UIApplication.shared.canOpenURL($0) },
        urlOpener: { UIApplication.shared.open($0) }
      )
    }
    uiActionHandler = { weakSelf?.mapModel(.external(.ui($0))) }
    weakSelf = self

    mapAdapter.events.addObserver { [weak self] in
      self?.mapModel(.external(.map($0)))
    }.dispose(in: disposePool)
  }
}

