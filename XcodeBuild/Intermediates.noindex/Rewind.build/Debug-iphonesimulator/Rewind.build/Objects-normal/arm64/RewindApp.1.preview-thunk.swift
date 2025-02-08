import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/RewindApp.swift", line: 1)
//
//  RewindApp.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI
import VGSL

@main
struct RewindApp: App {
  fileprivate let graph = AppGraph()

  var body: some Scene {
    WindowGroup {
      RootView(
        rawMap: graph.mapAdapter.view,
        mapState: graph.mapState
      )
    }
  }
}

final class AppGraph {
  let mapModel: MapModel
  let mapAdapter: MapAdapter
  let mapState: ObservedVariable<MapState>
  let imageDetailsFactory: (Int) -> ImageDetailsModel
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
      addAnnotations: mapAdapter.add(annotations:),
      clearAnnotations: mapAdapter.clear,
      visibleAnnotations: Variable { mapAdapter.visibleAnnotations },
      setRegion: mapAdapter.set(region:animated:),
      requestAnnotations: { region in
        remotes.annotations(
          (region: region, yearRange: 1900...2000), // TODO
          completion: { result in
            switch result {
            case let .success((images, clusters)):
              weakSelf?.mapModel(.external(.loaded(images, clusters)))
            case .failure: break // TODO
            }
          }
        )
      },
      throttle: { mapAction in
        // TODO: simplify, no probably no need to pass mapaction itself
        throttler.throttle(mapAction, perform: { weakSelf?.mapModel($0) })
      }
    )
    self.mapAdapter = mapAdapter
    self.mapState = mapModel.$state.asObservedVariable()
    imageDetailsFactory = { cid in
      makeImageDetailsModel(load: remotes.imageDetails.mapArgs { cid })
    }
    weakSelf = self

    mapAdapter.events.addObserver { [weak self] in
      self?.mapModel(.external(.map($0)))
    }.dispose(in: disposePool)
  }
}
