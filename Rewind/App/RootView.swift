//
//  RootView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import MapKit
import SwiftUI

struct RootView: View {
  enum Map {
    struct State {
      var selectedImageKind: ImageRequestFilters.ImageKind
    }

    enum Action {
      case mapViewLoaded
      case controlsSizeChanged(CGSize)
    }

    typealias Store = ViewStore<State, Action>
  }

  let rawMap: UIView
  let mapControlsStore: MapControlsStore
  let floatingMenuStore: FloatingMenu.Store

  let appStore: AppModel.Store
  let mapStore: Map.Store

  @Namespace
  private var rootView

  var body: some View {
    NavigationStack(
      path: appStore.binding(\.navigationPath, send: { .navigation(.setPath($0)) })
    ) {
      content
        .navigationDestination(for: Screen.self) { screen in
          screen.view(namespace: rootView)
        }
    }
    .environment(\.gradientScheme, appStore.gradientScheme)
    .environment(\.maxRange, mapStore.selectedImageKind.maxRange)
    .environment(\.rootNamespace, rootView)
  }

  private var content: some View {
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
            store: mapControlsStore,
            appAction: appStore.callAsFunction,
            namespace: rootView,
            hasBottomSafeAreaInset: geometry.safeAreaInsets.bottom > 0,
            floatingMenu: { floatingMenu }
          ).readSize {
            mapStore(.controlsSizeChanged($0))
          }
        }.ignoresSafeArea(edges: .bottom)
      }
    }
    .navigationTitle("Rewind")
    .navigationBarTitleDisplayMode(.inline) // TODO: remove navbar background (or make is smooth)
    .delayedModifier(
      value: appStore.anyOverlayPresented,
      delay: appStore.anyOverlayPresented ? 0 : 1,
    ) { view, hasOverlays in
      view.mask {
        makeMask(hasOverlays: hasOverlays)
          .ignoresSafeArea()
      }
    }
    .alert(appStore.binding(\.alertModel, send: { _ in .alert(.dismiss) }))
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
          .zoomed(from: .searchButton, namespace: rootView)
      },
    )
    .sheet(
      item: appStore.binding(\.settingsStore, send: { _ in .settings(.dismiss) }),
      content: { identified in
        SettingsView(store: identified.value)
          .zoomed(from: .settingsButton, namespace: rootView)
      },
    )
  }

  var floatingMenu: FloatingMenu {
    FloatingMenu(
      store: floatingMenuStore
    )
  }

  @ViewBuilder
  private func makeMask(hasOverlays: Bool) -> some View {
    if hasOverlays {
      if #available(iOS 26.0, *) {
        ConcentricRectangle()
      } else {
        RoundedRectangle(cornerRadius: hasOverlays ? screenRadius : 0)
      }
    } else {
      Color.white
    }
  }
}

func makeRootMapStore(
  mapStore: MapViewModel.Store
) -> RootView.Map.Store {
  mapStore.bimap(
    state: { mapState in
      RootView.Map.State(
        selectedImageKind: mapState.filters.imageKind
      )
    },
    action: { action in
      switch action {
      case .mapViewLoaded:
        .mapViewLoaded
      case let .controlsSizeChanged(size):
        .controls(.sizeChanged(size))
      }
    }
  )
}

private let screenRadius = DeviceModel.getCurrent().screenRadius()

extension AppState {
  fileprivate var anyOverlayPresented: Bool {
    onboardingStore != nil
      || settingsStore != nil
      || searchStore != nil
      || navigationPath.count > 0
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
    mapStore: graph.rootViewMapStore
  )
}
#endif
