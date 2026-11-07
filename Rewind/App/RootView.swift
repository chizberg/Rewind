//
//  RootView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import MapKit
import SwiftUI
import VGSL

struct RootView: View {
  enum Map {
    struct State: Equatable {
      var selectedImageKind: ImageRequestFilters.ImageKind
      var locationAccessGranted: Bool
      var toolbarKind: MapState.ToolbarKind
      var sheetDetent: BottomSheet.State.Detent
      var isLoading: Bool
      var isYearRangeModified: Bool
      var isMapZoomedOut: Bool
      var emptyResultCount: Int
    }

    enum Action {
      case mapViewLoaded
      case locationButtonTapped
      case sheetStateChanged(BottomSheet.State)
      case setSheetDetent(BottomSheet.State.Detent)
    }

    typealias Store = ViewStore<State, Action>
  }

  let rawMap: UIView
  let regionImageListStore: ImageListModel.Store
  let floatingMenuStore: FloatingMenu.Store

  let appStore: AppModel.Store
  let mapStore: Map.Store
  let mapBottomInset: ObservedVariable<CGFloat>

  @Namespace
  private var rootView
  @Environment(\.hostGeometry)
  private var hostGeometry
  @Environment(\.zoomSourceViews)
  private var zoomSourceViews

  var body: some View {
    content
      .environment(\.gradientScheme, appStore.gradientScheme)
      .environment(\.maxRange, mapStore.selectedImageKind.maxRange)
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

      Group {
        if mapStore.toolbarKind == .map {
          FloatingMenuOverlay(
            menu: floatingMenu,
            bottomInset: mapBottomInset,
            verticalBarEdge: hostGeometry?.verticalBarEdge,
          )
        }
      }
      .modify { view in
        if #available(iOS 26, *) {
          GlassEffectContainer { view }
        } else {
          ZStack { view }
        }
      }

      if let hostGeometry {
        ViewControllerRepresentable {
          BottomSheet(
            detent: mapStore.state.ov.map(\.sheetDetent).skipRepeats(),
            height: hostGeometry.size.height,
          ) { state in
            let wrapper = RegionImagesSheetController(
              content: UIHostingController(rootView: RegionImageList(
                store: regionImageListStore,
                appStore: appStore,
                mapStore: mapStore,
                fullscreenProgress: state.map(\.fullscreenProgress).skipRepeats(),
                isSheetAtTop: state.map { $0.fullscreenProgress == 1 }.skipRepeats()
                  .asObservedVariable(),
                hostGeometry: hostGeometry,
                zoomSourceViews: zoomSourceViews,
                namespace: rootView,
              )),
              state: state,
            )
            state.newValues.addObserver { state in
              let animation = Animation.interpolatingSpring(
                BottomSheet.settleSpring,
                initialVelocity: state.velocity,
              )
              withAnimation(UIView.inheritedAnimationDuration > 0 ? animation : nil) {
                mapStore(.sheetStateChanged(state))
              }
            }.dispose(in: wrapper.disposePool)
            return wrapper
          }
        }
        .ignoresSafeArea()
      }
    }
    .navigationTitle(mapStore.toolbarKind.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarRole(.editor)
    .modify { view in
      if #available(iOS 26, *) {
        view
      } else {
        view.toolbarBackground(.visible, for: .navigationBar)
      }
    }
    .toolbar {
      toolbarItems.verticalPreferred()
    }
    .animation(.default, value: mapStore.toolbarKind)
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

  @ToolbarContentBuilder
  private var toolbarItems: some ToolbarContent {
    switch mapStore.toolbarKind {
    case .map: searchAndLocation
    case .sheet: sheetToolbar
    }
  }

  private var searchAndLocation: some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      Button {
        appStore(.search(.present))
      } label: {
        Label("Search", systemImage: "magnifyingglass")
      }
      .zoomTransitionSource(.searchButton, namespace: rootView)

      Button {
        mapStore(.locationButtonTapped)
      } label: {
        Label(
          "My location",
          systemImage: mapStore.locationAccessGranted ? "location" : "location.slash",
        )
      }
    }
  }

  @ToolbarContentBuilder
  private var sheetToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        mapStore(.setSheetDetent(.normal))
      } label: {
        Label("Back", systemImage: "chevron.left")
      }
    }
    if mapStore.isLoading {
      ToolbarItem(placement: .topBarTrailing) {
        ProgressView()
      }
      .modify {
        if #available(iOS 26, *) {
          $0.sharedBackgroundVisibility(.hidden)
        } else {
          $0
        }
      }
    }
    if let sorting = regionImageListStore.sorting {
      ToolbarItem(placement: .topBarTrailing) {
        SortingMenu(viewStore: regionImageListStore, sorting: sorting)
      }
    }
    if #available(iOS 26, *) {
      ToolbarSpacer(.fixed, placement: .topBarTrailing)
    }
    ToolbarItemGroup(placement: .topBarTrailing) {
      Button {
        appStore(.imageList(.presentFavorites(source: .imageList(.favoritesButton))))
      } label: {
        Label("Favorites", systemImage: "star")
          .modify { label in
            if #available(iOS 26, *) {
              label
            } else {
              label.foregroundStyle(.tint)
            }
          }
      }

      Button {
        appStore(.settings(.present))
      } label: {
        Label("Settings", systemImage: "gearshape")
      }
      .zoomTransitionSource(.settingsButton, namespace: rootView)
    }
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
      SwiftUI.Color.white
    }
  }
}

func makeRootMapStore(
  mapStore: MapViewModel.Store
) -> RootView.Map.Store {
  mapStore.bimap(
    state: { mapState in
      RootView.Map.State(
        selectedImageKind: mapState.filters.imageKind,
        locationAccessGranted: mapState.locationState.isAccessGranted,
        toolbarKind: mapState.toolbarKind,
        sheetDetent: mapState.sheetDetent,
        isLoading: mapState.isLoading,
        isYearRangeModified: mapState.filters.isRangeModified,
        isMapZoomedOut: mapState.region.span.latitudeDelta > 60,
        emptyResultCount: mapState.emptyResultCount,
      )
    },
    action: { action in
      switch action {
      case .mapViewLoaded:
        .mapViewLoaded
      case .locationButtonTapped:
        .locationButtonTapped
      case let .sheetStateChanged(state):
        .sheet(.stateChanged(state))
      case let .setSheetDetent(detent):
        .sheet(.setDetent(detent))
      }
    }
  ).skipRepeats()
}

private struct FloatingMenuOverlay: View {
  var menu: FloatingMenu
  var bottomInset: ObservedVariable<CGFloat>
  var verticalBarEdge: Edge?

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      menu
    }
    .padding(.horizontal, 25)
    .padding(.bottom, bottomInset.wrappedValue + 10)
    .transaction(value: bottomInset.wrappedValue) {
      if $0.animation == nil { $0.disablesAnimations = true }
    }
    .ignoresSafeArea(edges: Edge.Set.bottom.union(verticalBarEdge.map { Edge.Set($0) } ?? []))
  }
}

// A separate view so the stores are read in body and stay live inside the hosting controller
private struct RegionImageList: View {
  var store: ImageListModel.Store
  var appStore: AppModel.Store
  var mapStore: RootView.Map.Store
  var fullscreenProgress: ObservableVariable<CGFloat>
  var isSheetAtTop: ObservedVariable<Bool>
  var hostGeometry: HostGeometry
  var zoomSourceViews: ZoomSourceViews?
  var namespace: Namespace.ID

  var body: some View {
    imageList
      .environment(\.sheetFullscreenProgress, fullscreenProgress)
      .delayedModifier(
        value: isSheetAtTop.wrappedValue,
        delay: isSheetAtTop.wrappedValue ? 0.5 : 0,
      ) { view, isSheetAtTop in
        view.scrollIndicators(isSheetAtTop ? .automatic : .hidden)
      }
      .overlay(alignment: verticalBarEdge == .leading ? .topLeading : .topTrailing) {
        ZStack {
          if mapStore.toolbarKind == .map {
            favoritesAndSettings
              .overlay(alignment: verticalBarEdge == .leading ? .topTrailing : .topLeading) {
                loadingIndicator
                  .alignmentGuide(.leading) { $0.width + 8 }
                  .alignmentGuide(.trailing) { _ in -8 }
              }
              .animation(.default, value: mapStore.isLoading)
              .padding(15)
              .transition(.blurReplace)
          }
        }
        .ignoresSafeArea(edges: verticalBarEdge.map { Edge.Set($0) } ?? [])
        .animation(.default, value: mapStore.toolbarKind)
      }
      .overlay {
        if mapStore.sheetDetent == .minimized {
          Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
              mapStore(.setSheetDetent(.normal))
            }
        }
      }
      .environment(\.gradientScheme, appStore.gradientScheme)
      .environment(\.maxRange, mapStore.selectedImageKind.maxRange)
      .environment(\.zoomSourceViews, zoomSourceViews)
      .environment(\.hostGeometry, hostGeometry)
  }

  private var imageList: some View {
    ImageList(
      viewStore: store,
      padding: 13,
      placeholders: placeholders,
      placeholderChange: mapStore.emptyResultCount,
      hint: emptyHint,
    )
  }

  @ViewBuilder
  private var loadingIndicator: some View {
    if mapStore.isLoading {
      ProgressView()
        .frame(width: 46, height: 46)
        .transition(.blurReplace)
    }
  }

  private var placeholders: [EmptyListPlaceholder] {
    mapStore.isYearRangeModified ? EmptyListPlaceholder.map : EmptyListPlaceholder.general
  }

  private var emptyHint: LocalizedStringResource? {
    if mapStore.isYearRangeModified {
      return "Try widening the years"
    }
    if mapStore.selectedImageKind == .painting {
      return "Try switching to photos"
    }
    if !mapStore.isMapZoomedOut {
      return "Try moving the map or zooming out"
    }
    return nil
  }

  private var favoritesAndSettings: some View {
    let isVertical = verticalBarEdge != nil
    let size = CGSize(width: 52, height: 46)
    let buttonSize = isVertical ? size.swapped() : size
    return AxisStack(axis: isVertical ? .vertical : .horizontal, spacing: 0) {
      Button {
        appStore(.imageList(.presentFavorites(source: .imageList(.favoritesButton))))
      } label: {
        Label("Favorites", systemImage: "star")
          .labelStyle(.iconOnly)
          .frame(size: buttonSize)
      }
      .accessibilityShowsLargeContentViewer()
      .zoomTransitionSource(.imageList(.favoritesButton))

      Button {
        appStore(.settings(.present))
      } label: {
        Label("Settings", systemImage: "gearshape")
          .labelStyle(.iconOnly)
          .frame(size: buttonSize)
      }
      .accessibilityShowsLargeContentViewer()
      .zoomTransitionSource(.settingsButton, namespace: namespace)
    }
    .imageScale(.large)
    .modify { view in
      if #available(iOS 26, *) {
        view.fontWeight(.medium)
      } else {
        view
      }
    }
    .dynamicTypeSize(.large)
    .foregroundStyle(.primary)
    .padding(isVertical ? .vertical : .horizontal, 2)
    .blurBackground(in: Capsule())
  }

  private var verticalBarEdge: Edge? {
    hostGeometry.verticalBarEdge
  }
}

extension MapState.ToolbarKind {
  fileprivate var title: Text {
    switch self {
    case .map: Text("Rewind")
    case .sheet: Text(verbatim: "")
    }
  }
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
    regionImageListStore: graph.regionImageListStore,
    floatingMenuStore: graph.floatingMenuStore,
    appStore: graph.appStore,
    mapStore: graph.rootViewMapStore,
    mapBottomInset: graph.mapBottomInset,
  )
  .environment(
    \.hostGeometry,
    HostGeometry(size: CGSize(width: 402, height: 874), safeAreaInsets: .zero)
  )
}
#endif
