import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/ContentView.swift", line: 1)
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
    ZStack {
      ViewRepresentable {
        rawMap
      }
      Text("\(mapState.previews.count)")
    }
  }
}

#Preview {
  @Previewable @State var graph = AppGraph()

  ContentView(
    rawMap: graph.mapAdapter.view, mapState: graph.mapState
  )
}
