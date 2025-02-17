//
//  RewindApp.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI

@main
struct RewindApp: App {
  fileprivate let graph = AppGraph()

  var body: some Scene {
    WindowGroup {
      RootView(
        rawMap: graph.mapAdapter.view,
        mapState: graph.mapState,
        mapActionHandler: { graph.mapModel(.external(.ui($0))) },
        appState: graph.appState,
        appActionHandler: { graph.appModel($0) },
        imageDetailsFactory: graph.imageDetailsFactory
      )
    }
  }
}
