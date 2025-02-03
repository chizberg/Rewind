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

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: __designTimeString("#9526_0", fallback: "globe"))
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text(__designTimeString("#9526_1", fallback: "Hello, world!"))
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
