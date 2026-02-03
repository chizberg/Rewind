//
//  RewindApp.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI

@main
struct RewindApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self)
  var appDelegate

  let graph: AppGraph

  init() {
    graph = AppGraph()

    graph.orientationLock = appDelegate.orientationLock?.asProperty()
  }

  var body: some Scene {
    WindowGroup {
      RootView(
        rawMap: graph.mapAdapter.view,
        mapStore: graph.mapStore,
        appStore: graph.appStore
      )
      .environment(\.openURL, OpenURLAction {
        graph.urlOpener($0)
        return .handled
      })
    }
  }
}
