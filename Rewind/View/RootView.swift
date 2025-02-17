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
          )
        ).padding()

        ThumbnailsView(
          namespace: rootView,
          previews: mapState.previews,
          onSelected: {
            mapActionHandler(.thumbnailSelected($0))
          }
        )
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
          state: model.$state.asObservedVariable()
        )
        .navigationTransition(.zoom(sourceID: previewedImage.cid, in: rootView))
      }
    )
  }
}

private struct ThumbnailsView: View {
  var namespace: Namespace.ID
  let previews: [Model.Image]
  let onSelected: (Model.Image) -> Void
  private let leadingEdge = 0

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          // Empty view to scroll to (including paddings)
          Color.clear.frame(width: 0, height: 0).id(leadingEdge)

          LazyHStack {
            ForEach(previews) { image in
              SquishyButton {
                onSelected(image)
              } label: { _ in
                ThumbnailView(image: image, size: thumbnailSize)
                  .matchedTransitionSource(id: image.cid, in: namespace)
              }
            }
          }.padding()
        }
      }
      .onChange(of: previews) {
        withAnimation {
          proxy.scrollTo(leadingEdge, anchor: .leading)
        }
      }
    }.frame(height: thumbnailSize.height)
      .animation(.spring(), value: previews)
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
