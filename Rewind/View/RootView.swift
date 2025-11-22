//
//  RootView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import BezelKit
import MapKit
import SwiftUI

struct RootView: View {
  let rawMap: UIView
  let mapStore: ViewStore<MapState, MapAction.External.UI>
  let appStore: ViewStore<AppState, AppAction>

  enum TransitionSource {
    static let settings = "settings"
    static let thumbnail = "thumbnail"
    static let viewAsListButton = "view as list button"
    static let favoritesButton = "favorites button"
  }

  @Namespace
  private var rootView

  var body: some View {
    ZStack(alignment: .bottom) {
      ViewRepresentable {
        rawMap
      }
      .ignoresSafeArea()
      .task { // TODO: move to onboarding
        mapStore(.mapViewLoaded)
      }

      GeometryReader { geometry in
        VStack {
          Spacer()
          MapControls(
            mapStore: mapStore,
            appStore: appStore,
            namespace: rootView,
            hasBottomSafeAreaInset: geometry.safeAreaInsets.bottom > 0
          )
        }.ignoresSafeArea(edges: .bottom)
      }
    }
    .alert(
      Binding(
        get: { appStore.alertModel },
        set: { _ in appStore(.alert(.dismiss)) }
      )
    )
    .mask(RoundedRectangle(cornerRadius: CGFloat.deviceBezel).ignoresSafeArea())
    .fullScreenCover(
      item: Binding(
        get: { appStore.previewedImage },
        set: { _ in appStore(.imageDetails(.dismiss)) }
      ),
      content: { identified in
        let viewStore = identified.value
        ImageDetailsView(
          viewStore: viewStore
        )
        .navigationTransition(
          .zoom(
            sourceID: "\(viewStore.cid) \(viewStore.openSource)", in: rootView
          )
        )
      }
    )
    .fullScreenCover(
      item: Binding(
        get: { appStore.previewedList },
        set: { _ in appStore(.imageList(.dismiss)) }
      ),
      content: { identified in
        let viewStore = identified.value
        ImageList(
          viewStore: viewStore
        ).navigationTransition(.zoom(sourceID: viewStore.matchedTransitionSourceName, in: rootView))
      }
    )
    .sheet(
      item: Binding(
        get: { appStore.settingsStore },
        set: { _ in appStore(.settings(.dismiss)) }
      ),
      content: { identified in
        SettingsView(store: identified.value)
          .navigationTransition(
            .zoom(sourceID: TransitionSource.settings, in: rootView)
          )
      }
    )
  }
}

#Preview {
  @Previewable @State var graph = AppGraph()

  RootView(
    rawMap: graph.mapAdapter.view,
    mapStore: graph.mapStore,
    appStore: graph.appStore
  )
}
