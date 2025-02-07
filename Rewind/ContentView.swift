//
//  ContentView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI
import MapKit

struct ContentView: View {
  let rawMap: UIView
  @ObservedVariable
  var mapState: MapState

  var body: some View {
    ZStack(alignment: .bottom) {
      ViewRepresentable {
        rawMap
      }.ignoresSafeArea()

      ThumbnailsView(previews: mapState.previews)
    }
  }
}

private struct ThumbnailsView: View {
  let previews: [Model.Image]
  private let leadingEdge = 0

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          // Empty view to scroll to (including paddings)
          Color.clear.frame(width: 0, height: 0).id(leadingEdge)

          LazyHStack {
            ForEach(previews) {
              ThumbnailView(image: $0, size: thumbnailSize)
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

  ContentView(
    rawMap: graph.mapAdapter.view, mapState: graph.mapState
  )
}
