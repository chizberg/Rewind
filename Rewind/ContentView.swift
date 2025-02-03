//
//  ContentView.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import SwiftUI
import MapKit

struct ContentView: View {
  @State
  private var rp = RequestPerformer(urlRequestPerformer: URLSession.shared.data)

  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
    }
    .padding()
    .onAppear {
      Task {
        do {
          let foo = try await rp.perform(
            request: .byBounds(
              zoom: 17,
              coordinates: initialRegion.geoJSONCoordinates,
              startAt: Date().timeIntervalSince1970,
              yearRange: 1900...2000
            )
          )
          print(foo)
        } catch {
          print("fuck")
        }
      }
    }
  }
}

let initialRegion = Region(
  center: Coordinate(latitude: 44.821782, longitude: 20.455564),
  span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
)

#Preview {
  ContentView()
}
