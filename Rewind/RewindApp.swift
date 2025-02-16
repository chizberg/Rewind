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
        imageDetailsFactory: graph.imageDetailsFactory,
        actionHandler: graph.uiActionHandler
      )
    }
  }
}
