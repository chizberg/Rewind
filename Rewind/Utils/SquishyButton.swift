//
//  SquishyButton.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import SwiftUI

struct SquishyButton<Content: View>: View {
  var scale: CGFloat = 0.9
  var action: () -> Void
  var label: (Bool) -> Content

  @State
  private var isPressed = false

  var body: some View {
    label(isPressed)
      .scaleEffect(isPressed ? scale : 1)
      .gesture(
        _ButtonGesture(
          action: action,
          pressing: { _ in } // does not react as fast as DragGesture
        )
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            isPressed = true
          }
          .onEnded { _ in
            isPressed = false
          }
      )
      .animation(
        .spring(
          response: 0.3,
          dampingFraction: 0.7,
          blendDuration: 0.3
        ),
        value: isPressed
      )
  }
}

#Preview {
  SquishyButton {
    print(UUID().uuidString)
  } label: { pressed in
    Image(systemName: pressed ? "play.fill" : "play")
      .font(.system(size: 100))
  }
}
