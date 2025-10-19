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
  @ObservedVariable
  var mapState: MapState
  var mapActionHandler: (MapAction.External.UI) -> Void
  @ObservedVariable
  var appState: AppState
  var appActionHandler: (AppAction) -> Void
  var imageDetailsFactory: (Model.Image) -> ImageDetailsModel
  @Namespace
  private var rootView

  var body: some View {
    ZStack(alignment: .bottom) {
      ViewRepresentable {
        rawMap
      }
      .ignoresSafeArea()
      .task { // TODO: move to onboarding
        mapActionHandler(.mapViewLoaded)
      }

      MapBlurView(thumbnailsEmpty: mapState.previews.isEmpty)

      VStack {
        ExpandableControls(
          yearRange: Binding(
            get: { mapState.yearRange },
            set: { mapActionHandler(.yearRangeChanged($0)) }
          ),
          mapType: Binding(
            get: { mapState.mapType },
            set: { mapActionHandler(.mapTypeSelected($0)) }
          ),
          staticItems: [
            .init(id: "location", iconName: "location") {
              mapActionHandler(.locationButtonTapped)
            },
          ]
        ).padding()

        horizontalScroll
      }
    }
    .mask(RoundedRectangle(cornerRadius: CGFloat.deviceBezel).ignoresSafeArea())
    .fullScreenCover(
      item: Binding(
        get: { appState.previewedImage },
        set: { item in
          if item == nil { appActionHandler(.imagePreviewClosed) }
        }
      ),
      content: { previewedImage in
        let model = imageDetailsFactory(previewedImage)
        ImageDetailsView(
          model: model,
          state: model.$state.asObservedVariable(),
          showCloseButton: true
        )
        .navigationTransition(.zoom(sourceID: previewedImage.cid, in: rootView))
      }
    )
    .fullScreenCover(
      isPresented: Binding(
        get: { appState.favoritesPresented },
        set: { if !$0 { appActionHandler(.favoritesClosed) } }
      ),
      content: {
        ImageList(
          title: "Favorites",
          images: appState.favorites,
          imageDetailsFactory: imageDetailsFactory,
          emptyLabel: { VStack {
            Text("💔").font(.largeTitle)
            Text("Nothing here yet")
          }}
        )
        .navigationTransition(.zoom(sourceID: "favorites", in: rootView))
      }
    )
    .fullScreenCover(
      isPresented: Binding(
        get: { appState.settingsPresented },
        set: { if !$0 { appActionHandler(.settingsClosed) } }
      ),
      content: {
        Text("TBD")
          .font(.largeTitle.bold())
          .foregroundColor(.white)
          .navigationTransition(.zoom(sourceID: "settings", in: rootView))
          .presentationBackground(.red)
      }
    )
    .fullScreenCover(
      item: Binding(
        get: { appState.previewedList },
        set: { item in
          if item == nil { appActionHandler(.listPreviewClosed) }
        }
      ),
      content: { identifiedList in
        ImageList(
          title: "Images",
          images: identifiedList.value,
          imageDetailsFactory: imageDetailsFactory,
          emptyLabel: { EmptyView() }
        )
        .presentationBackground(.clear)
      }
    )
  }

  private var horizontalScroll: some View {
    AutoscrollingScrollView(scrollOnChangeOf: mapState.previews) {
      LazyHStack(spacing: 8) {
        VStack {
          makeBottomScrollButton(
            iconName: "star",
            sourceID: "favorites",
            tintColor: .yellow
          ) {
            appActionHandler(.favoritesButtonTapped)
          }

          makeBottomScrollButton(
            iconName: "gearshape",
            sourceID: "settings",
            tintColor: nil
          ) {
            appActionHandler(.settingsButtonTapped)
          }
        }.frame(width: 75)

        ThumbnailsView(
          namespace: rootView,
          previews: mapState.previews,
          onSelected: { appActionHandler(.previewImage($0)) }
        )
      }
      .padding(.horizontal)
    }
    .frame(height: thumbnailSize.height)
  }

  private func makeBottomScrollButton(
    iconName: String,
    sourceID: String,
    tintColor: Color?,
    action: @escaping () -> Void
  ) -> some View {
    ZStack {
      BlurView(style: .systemThickMaterial)

      Image(systemName: iconName)
        .font(.title2.bold())
    }
    .cornerRadius(15)
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
    LazyHStack {
      ForEach(previews) { image in
        ThumbnailView(image: image, size: thumbnailSize)
          .matchedTransitionSource(id: image.cid, in: namespace)
          .onTapGesture { onSelected(image) }
      }
    }
    .animation(.spring(), value: previews)
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
    mapState: graph.mapState,
    mapActionHandler: { graph.mapModel(.external(.ui($0))) },
    appState: graph.appState,
    appActionHandler: { graph.appModel($0) },
    imageDetailsFactory: graph.imageDetailsFactory
  )
}
