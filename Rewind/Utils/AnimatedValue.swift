//
//  AnimatedValue.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 27. 9. 2026..
//

import SwiftUI

extension View {
  func withAnimatedValue<V: Equatable>(
    _ value: V,
    animation: Animation = .default,
    @ViewBuilder content: @escaping (Self, V?) -> some View,
  ) -> some View {
    ValueAnimator(
      value: value,
      animation: animation,
      content: { v in content(self, v) }
    )
  }
}

private struct ValueAnimator<V: Equatable, Content: View>: View {
  var value: V
  var animation: Animation
  @ViewBuilder
  var content: (V?) -> Content

  @State
  private var animatedValue: V?
  @State
  private var didAppear = false

  var body: some View {
    content(animatedValue)
      .onUIKitAppear {
        if !didAppear {
          updateValueAnimated()
          didAppear = true
        }
      }
      .onChange(of: value) {
        if didAppear {
          updateValueAnimated()
        }
      }
  }

  private func updateValueAnimated() {
    withAnimation(animation) {
      animatedValue = value
    }
  }
}
