//
//  ViewRepresentable.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import SwiftUI

struct ViewRepresentable<V: UIView>: UIViewRepresentable {
  private let factory: () -> V
  private let updater: (V) -> Void

  init(
    factory: @escaping () -> V,
    updater: @escaping (V) -> Void = { _ in }
  ) {
    self.factory = factory
    self.updater = updater
  }

  func makeUIView(context: Context) -> V {
    factory()
  }

  func updateUIView(_ v: V, context: Context) {
    updater(v)
  }
}
