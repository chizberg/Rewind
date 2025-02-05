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

//      ScrollView {
//        LazyHStack {
//          ForEach(mapState.previews) {
//            ThumbnailView(image: $0)
//              .frame(width: 100, height: 100)
//          }
//        }
//      }
    }
  }
}

#Preview {
  @Previewable @State var graph = AppGraph()

  ContentView(
    rawMap: graph.mapAdapter.view, mapState: graph.mapState
  )
}
