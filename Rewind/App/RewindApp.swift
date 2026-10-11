//
//  RewindApp.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI

struct RewindApp: App {
  let graph: AppGraph

  init() {
    graph = AppGraph()
  }

  var body: some Scene {
    WindowGroup {
      ViewControllerRepresentable(factory: {
        graph.navigator.setRoot(
          RootView(
            rawMap: graph.map.value.view,
            mapControlsStore: graph.mapControlsStore,
            floatingMenuStore: graph.floatingMenuStore,
            appStore: graph.appStore,
            mapStore: graph.rootViewMapStore,
          )
          .environment(\.openURL, OpenURLAction {
            graph.urlOpener($0)
            return .handled
          })
        )
        return graph.navigator.navigationController
      })
      .ignoresSafeArea()
      .statusBarHidden(
        graph.appStore.navigationPath.last?.statusBarHidden ?? false
      )
    }
  }
}
