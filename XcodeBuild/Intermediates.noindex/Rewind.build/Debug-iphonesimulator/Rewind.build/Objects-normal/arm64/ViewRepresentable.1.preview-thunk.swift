import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/Utils/ViewRepresentable.swift", line: 1)
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

  func makeUIView(context _: Context) -> V {
    factory()
  }

  func updateUIView(_ v: V, context _: Context) {
    updater(v)
  }
}

struct ViewControllerRepresentable<V: UIViewController>: UIViewControllerRepresentable {
  private let factory: () -> V
  private let updater: (V) -> Void

  init(
    factory: @escaping () -> V,
    updater: @escaping (V) -> Void = { _ in }
  ) {
    self.factory = factory
    self.updater = updater
  }
  
  func makeUIViewController(context _: Context) -> V {
    factory()
  }

  func updateUIViewController(_ v: V, context _: Context) {
    updater(v)
  }
}
