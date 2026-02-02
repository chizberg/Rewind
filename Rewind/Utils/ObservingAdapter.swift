//
//  ObservingAdapter.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 4. 1. 2026.
//

import SwiftUI

struct ObservingAdapter<Value: Observable, Content: View>: View {
  var value: Value
  @ViewBuilder
  var content: (Value) -> Content

  var body: some View {
    content(value)
  }
}

extension Observable {
  func observe(
    @ViewBuilder content: @escaping (Self) -> some View
  ) -> some View {
    ObservingAdapter(value: self, content: content)
  }
}
