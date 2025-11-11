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

      MapBlurView(thumbnailsEmpty: mapStore.previews.isEmpty)

      VStack {
        ExpandableControls(
          yearRange: Binding(
            get: { mapStore.yearRange },
            set: { mapStore(.yearRangeChanged($0)) }
          ),
          mapType: Binding(
            get: { mapStore.mapType },
            set: { mapStore(.mapTypeSelected($0)) }
          ),
          staticItems: [
            .init(
              id: "location",
              iconName: mapStore.locationState.isAccessGranted
                ? "location" : "location.slash"
            ) {
              mapStore(.locationButtonTapped)
            },
          ]
        ).padding()

        horizontalScroll
      }
    }
    .mask(RoundedRectangle(cornerRadius: CGFloat.deviceBezel).ignoresSafeArea())
    .fullScreenCover(
      item: Binding<Identified<ImageDetailsModel>?>(
        get: { appStore.previewedImage },
        set: { _ in appStore(.imageDetails(.dismiss)) }
      ),
      content: { previewedImage in
        let viewStore = previewedImage.value.viewStore
        ImageDetailsView(
          viewStore: viewStore,
          showCloseButton: true
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
      content: { previewedList in
        let viewStore = previewedList.value.viewStore
        ImageList(
          viewStore: viewStore
        ).navigationTransition(.zoom(sourceID: viewStore.matchedTransitionSourceName, in: rootView))
      }
    )
    .sheet(
      item: Binding(
        get: { appStore.settingsModel },
        set: { _ in appStore(.settings(.dismiss)) }
      ),
      content: { settingsModel in
        SettingsView(store: settingsModel.value.viewStore)
          .navigationTransition(
            .zoom(sourceID: TransitionSource.settings, in: rootView)
          )
      }
    )
    .alert(
      Binding(
        get: { appStore.alertModel },
        set: { _ in appStore(.alert(.dismiss)) }
      )
    )
  }

  private var horizontalScroll: some View {
    AutoscrollingScrollView(scrollOnChangeOf: mapStore.previews) {
      LazyHStack(spacing: 8) {
        VStack {
          makeBottomScrollButton(
            iconName: "star",
            sourceID: TransitionSource.favoritesButton
          ) {
            appStore(.imageList(.presentFavorites(source: TransitionSource.favoritesButton)))
          }

          makeBottomScrollButton(
            iconName: "list.bullet",
            sourceID: TransitionSource.viewAsListButton,
            action: {
              appStore(.imageList(
                .present(
                  mapStore.currentRegionImages,
                  source: TransitionSource.viewAsListButton,
                  title: "On the map"
                )
              ))
            }
          )

          makeBottomScrollButton(
            iconName: "gearshape",
            sourceID: TransitionSource.settings
          ) {
            appStore(.settings(.present))
          }
        }.frame(width: 75)

        ThumbnailsView(
          mapStore: mapStore,
          namespace: rootView,
          onSelected: {
            appStore(
              .imageDetails(
                .present(
                  $0,
                  source: TransitionSource.thumbnail
                )
              )
            )
          }
        )
      }
      .padding(.horizontal)
    }
    .frame(height: thumbnailSize.height)
    .animation(.spring().speed(2), value: mapStore.previews)
  }

  @ViewBuilder
  private func makeBottomScrollButton(
    iconName: String,
    sourceID: String,
    action: @escaping () -> Void
  ) -> some View {
    let radius: CGFloat = 20
    ZStack {
      if #available(iOS 26, *) {
        GlassView(radius: radius)
      } else {
        BlurView(style: .systemThickMaterial, radius: radius)
      }

      Image(systemName: iconName)
        .font(.title2.bold())
    }
    .cornerRadius(radius)
    .onTapGesture(perform: action)
    .matchedTransitionSource(id: sourceID, in: rootView)
  }
}

private enum TransitionSource {
  static let settings = "settings"
  static let thumbnail = "thumbnail"
  static let viewAsListButton = "view as list button"
  static let favoritesButton = "favorites button"
}

private struct ThumbnailsView: View {
  var mapStore: ViewStore<MapState, MapAction.External.UI>
  var namespace: Namespace.ID
  let onSelected: (Model.Image) -> Void
  private let leadingEdge = 0

  var body: some View {
    ForEach(mapStore.previews) { image in
      ThumbnailView(image: image, size: thumbnailSize)
        .matchedTransitionSource(
          id: "\(image.cid) \(TransitionSource.thumbnail)",
          in: namespace
        )
        .onTapGesture { onSelected(image) }
        .transition(.scale)
    }
  }
}

private struct AutoscrollingScrollView<Value: Equatable, Content: View>: View {
  var value: Value
  var content: Content

  private let leadingEdge = 0

  init(
    scrollOnChangeOf value: Value,
    @ViewBuilder content: () -> Content
  ) {
    self.value = value
    self.content = content()
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          // Empty view to scroll to (including paddings)
          Color.clear.frame(width: 0, height: 0).id(leadingEdge)

          content
        }
      }
      .onChange(of: value) {
        withAnimation {
          proxy.scrollTo(leadingEdge, anchor: .leading)
        }
      }
    }
  }
}

private let thumbnailSize = CGSize(width: 250, height: 187.5)

#Preview {
  @Previewable @State var graph = AppGraph()

  RootView(
    rawMap: graph.mapAdapter.view,
    mapStore: graph.mapStore,
    appStore: graph.appStore
  )
}
