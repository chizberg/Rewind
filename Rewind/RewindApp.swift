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
      ContentView(
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
  private let disposePool = AutodisposePool()

  init() {
    weak var weakSelf: AppGraph?
    let mapAdapter = MapAdapter()
    let requestPerformer = RequestPerformer(urlRequestPerformer: URLSession.shared.data)
    let imageLoader = ImageLoader(requestPerformer: requestPerformer)
    let throttledPerformer = ThrottledActionPerformer()

    let annotationLoader = AnnotationLoader(
      requestPerformer: requestPerformer,
      imageLoader: imageLoader
    )
    mapModel = makeMapModel(
      addAnnotations: mapAdapter.add(annotations:),
      clearAnnotations: mapAdapter.clear,
      visibleAnnotations: Variable { mapAdapter.visibleAnnotations },
      setRegion: mapAdapter.set(region:animated:),
      requestAnnotations: { region in
        annotationLoader.loadNewAnnotations(
          region: region,
          yearRange: 1900...2000, // TODO
          apply: { weakSelf?.mapModel(.external(.loaded($0, $1))) }
        )
      },
      throttledAction: { mapAction in
        throttledPerformer.throttledCall {
          weakSelf?.mapModel(mapAction)
        }
      }
    )
    self.mapAdapter = mapAdapter
    self.mapState = mapModel.$state.asObservedVariable()
    weakSelf = self

    mapAdapter.events.addObserver { [weak self] in
      self?.mapModel(.external(.map($0)))
    }.dispose(in: disposePool)
  }
}
