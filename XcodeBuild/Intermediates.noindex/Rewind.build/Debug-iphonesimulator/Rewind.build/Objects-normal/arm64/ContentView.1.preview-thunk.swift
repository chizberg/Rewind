import func SwiftUI.__designTimeBoolean
import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeString

#sourceLocation(
  file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/View/ContentView.swift",
  line: 1
)
//
//  ContentView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import MapKit
import SwiftUI

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
      ScrollView(.horizontal, showsIndicators: __designTimeBoolean("#7492_0", fallback: false)) {
        HStack(spacing: __designTimeInteger("#7492_1", fallback: 0)) {
          // Empty view to scroll to (including paddings)
          Color.clear.frame(
            width: __designTimeInteger("#7492_2", fallback: 0),
            height: __designTimeInteger("#7492_3", fallback: 0)
          ).id(leadingEdge)

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
