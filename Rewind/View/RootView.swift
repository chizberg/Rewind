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
  let mapStore: MapViewModel.Store
  let appStore: AppModel.Store

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
      .task {
        if appStore.onboardingStore == nil {
          mapStore(.mapViewLoaded)
        }
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
    .alert(appStore.binding(\.alertModel, send: { _ in .alert(.dismiss) }))
    .mask(RoundedRectangle(cornerRadius: CGFloat.deviceBezel).ignoresSafeArea())
    .fullScreenCover(
      item: appStore.binding(\.previewedImage, send: { _ in .imageDetails(.dismiss) }),
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
      item: appStore.binding(\.previewedList, send: { _ in .imageList(.dismiss) }),
      content: { identified in
        let viewStore = identified.value
        ImageList(
          viewStore: viewStore
        ).navigationTransition(.zoom(sourceID: viewStore.matchedTransitionSourceName, in: rootView))
      }
    )
    .fullScreenCover(
      item: appStore.binding(\.onboardingStore, send: { _ in .onboarding(.dismiss) }),
      content: { identified in
        OnboardingView(store: identified.value)
      }
    )
    .sheet(
      item: appStore.binding(\.settingsStore, send: { _ in .settings(.dismiss) }),
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
