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
            .init(id: "location", iconName: "location") {
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
        set: { _ in appStore(.imagePreviewClosed) }
      ),
      content: { previewedImage in
        let viewStore = previewedImage.value.viewStore
        ImageDetailsView(
          viewStore: viewStore,
          showCloseButton: true
        )
        .navigationTransition(
          .zoom(
            sourceID: viewStore.cid, in: rootView
          )
        )
      }
    )
    .fullScreenCover(
      item: Binding(
        get: { appStore.previewedList },
        set: { _ in appStore(.listPreviewClosed) }
      ),
      content: { previewedList in
        let viewStore = previewedList.value.viewStore
        ImageList(
          viewStore: viewStore
        ).navigationTransition(.zoom(sourceID: viewStore.matchedTransitionSourceName, in: rootView))
      }
    )
    .fullScreenCover(
      isPresented: Binding(
        get: { appStore.settingsPresented },
        set: { if !$0 { appStore(.settingsClosed) } }
      ),
      content: {
        Text("TBD")
          .font(.largeTitle.bold())
          .foregroundColor(.white)
          .navigationTransition(.zoom(sourceID: "settings", in: rootView))
          .presentationBackground(.red)
      }
    )
  }

  private var horizontalScroll: some View {
    AutoscrollingScrollView(scrollOnChangeOf: mapStore.previews) {
      LazyHStack(spacing: 8) {
        VStack {
          makeBottomScrollButton(
            iconName: "star",
            sourceID: "favorites button"
          ) {
            appStore(.favoritesButtonTapped(source: "favorites button"))
          }

          makeBottomScrollButton(
            iconName: "gearshape",
            sourceID: "settings"
          ) {
            appStore(.settingsButtonTapped)
          }
        }.frame(width: 75)

        ThumbnailsView(
          namespace: rootView,
          previews: mapStore.previews,
          onSelected: { appStore(.previewImage($0)) }
        )
      }
      .padding(.horizontal)
    }
    .frame(height: thumbnailSize.height)
    .animation(.spring().speed(2), value: mapStore.previews)
  }

  private func makeBottomScrollButton(
    iconName: String,
    sourceID: String,
    action: @escaping () -> Void
  ) -> some View {
    ZStack {
      let radius: CGFloat = 15
      if #available(iOS 26, *) {
        GlassView(radius: radius)
      } else {
        BlurView(style: .systemThickMaterial, radius: radius)
      }

      Image(systemName: iconName)
        .font(.title2.bold())
    }
    .onTapGesture(perform: action)
    .matchedTransitionSource(id: sourceID, in: rootView)
  }
}

private struct ThumbnailsView: View {
  var namespace: Namespace.ID
  let previews: [Model.Image]
  let onSelected: (Model.Image) -> Void
  private let leadingEdge = 0

  var body: some View {
    ForEach(previews) { image in
      ThumbnailView(image: image, size: thumbnailSize)
        .matchedTransitionSource(id: image.cid, in: namespace)
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
