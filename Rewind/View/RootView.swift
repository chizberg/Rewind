//
//  ContentView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI
import MapKit
import BezelKit

struct RootView: View {
  let rawMap: UIView
  @ObservedVariable
  var mapState: MapState
  var imageDetailsFactory: (Int) -> ImageDetailsModel
  var actionHandler: (MapAction.External.UI) -> Void
  @Namespace
  private var rootView

  var body: some View {
    ZStack(alignment: .bottom) {
      ViewRepresentable {
        rawMap
      }
      .cornerRadius(CGFloat.deviceBezel)
      .ignoresSafeArea()


      ThumbnailsView(
        namespace: rootView,
        previews: mapState.previews,
        onSelected: {
          actionHandler(.thumbnailSelected($0))
        }
      )
    }.fullScreenCover(
      item: Binding(
        get: { mapState.previewedImage },
        set: { item in
          // TODO: handle other items
          if item == nil { actionHandler(.previewClosed) }
        }
      ),
      content: { previewedImage in
        let model = imageDetailsFactory(previewedImage.cid)
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
              } label: {
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
    imageDetailsFactory: graph.imageDetailsFactory,
    actionHandler: graph.uiActionHandler
  )
}
