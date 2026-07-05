//
//  RootView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import MapKit
import SwiftUI

struct RootView: View {
  let rawMap: UIView

  let mapControlsStore: MapControlsStore
  let floatingMenuStore: FloatingMenu.Store
  let appStore: AppModel.Store

  @ObservedVariable
  var selectedImageKind: ImageRequestFilters.ImageKind
  var onMapLoaded: () -> Void

  enum TransitionSource {
    static let settings = "settings"
    static let thumbnail = "thumbnail"
    static let viewAsListButton = "view as list button"
    static let favoritesButton = "favorites button"
    static let pullUpCard = "pull up card"
    static let search = "search"
  }

  @Namespace
  private var rootView

  var body: some View {
    content
      .environment(\.gradientScheme, appStore.gradientScheme)
      .environment(\.maxRange, selectedImageKind.maxRange)
  }

  private var content: some View {
    ZStack(alignment: .bottom) {
      ViewRepresentable {
        rawMap
      }
      .ignoresSafeArea()
      .task {
        if appStore.onboardingStore == nil {
          onMapLoaded()
        }
      }

      GeometryReader { geometry in
        VStack {
          Spacer()
          MapControls(
            store: mapControlsStore,
            appAction: appStore.callAsFunction,
            namespace: rootView,
            hasBottomSafeAreaInset: geometry.safeAreaInsets.bottom > 0,
            floatingMenu: { floatingMenu }
          )
        }.ignoresSafeArea(edges: .bottom)
      }
    }
    .overlay(alignment: .topTrailing) {
      Text("Rewind <<")
        .font(.caption.weight(.semibold))
        .opacity(0.3)
        .padding(3)
        .padding(.horizontal, 2)
    }
    .alert(appStore.binding(\.alertModel, send: { _ in .alert(.dismiss) }))
    .delayedModifier(
      value: appStore.anyOverlayPresented,
      delay: appStore.anyOverlayPresented ? 0 : 1,
    ) { view, hasOverlays in
      view.mask(
        RoundedRectangle(cornerRadius: hasOverlays ? screenRadius : 0)
          .ignoresSafeArea(),
      )
    }
    .fullScreenCover(
      item: appStore.binding(\.previewedImage, send: { _ in .imageDetails(.dismiss) }),
      content: { identified in
        let viewStore = identified.value
        ImageDetailsView(
          viewStore: viewStore,
        )
        .navigationTransition(
          .zoom(
            sourceID: "\(viewStore.image.cid) \(viewStore.openSource)", in: rootView,
          ),
        )
      },
    )
    .fullScreenCover(
      item: appStore.binding(\.previewedList, send: { _ in .imageList(.dismiss) }),
      content: { identified in
        let viewStore = identified.value
        ImageList(
          viewStore: viewStore,
        ).navigationTransition(.zoom(sourceID: viewStore.matchedTransitionSourceName, in: rootView))
      },
    )
    .fullScreenCover(
      item: appStore.binding(\.onboardingStore, send: { _ in .onboarding(.dismiss) }),
      content: { identified in
        OnboardingView(store: identified.value)
      },
    )
    .sheet(
      item: appStore.binding(\.searchStore, send: { _ in .search(.dismiss) }),
      content: { identified in
        let viewStore = identified.value
        SearchView(store: viewStore)
          .navigationTransition(.zoom(sourceID: TransitionSource.search, in: rootView))
      },
    )
    .sheet(
      item: appStore.binding(\.settingsStore, send: { _ in .settings(.dismiss) }),
      content: { identified in
        SettingsView(store: identified.value)
          .navigationTransition(
            .zoom(sourceID: TransitionSource.settings, in: rootView),
          )
      },
    )
  }

  var floatingMenu: FloatingMenu {
    FloatingMenu(
      store: floatingMenuStore,
      namespace: rootView
    )
  }
}

private let screenRadius = DeviceModel.getCurrent().screenRadius()

extension AppState {
  fileprivate var anyOverlayPresented: Bool {
    previewedImage != nil
      || previewedList != nil
      || onboardingStore != nil
      || settingsStore != nil
      || searchStore != nil
  }
}

#if DEBUG
#Preview {
  @Previewable @State var graph = AppGraph()

  RootView(
    rawMap: graph.map.value.view,
    mapControlsStore: graph.mapControlsStore,
    floatingMenuStore: graph.floatingMenuStore,
    appStore: graph.appStore,
    selectedImageKind: graph.selectedImageKind,
    onMapLoaded: graph.onMapLoaded,
  )
}
#endif
