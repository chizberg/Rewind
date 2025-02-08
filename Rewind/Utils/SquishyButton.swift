//
//  SquishyButton.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 08.02.2025.
//

import SwiftUI

struct SquishyButton<Label: View>: View {
  var action: () -> Void
  var label: Label

  init(
    action: @escaping () -> Void,
    @ViewBuilder label: () -> Label
  ) {
    self.action = action
    self.label = label()
  }

  var body: some View {
    label
      .modifier(
        SquishyModifier(
          scale: 0.9,
          action: action
        )
      )
  }
}

private struct SquishyModifier: ViewModifier {
  @State
  private var isPressed = false

  var scale: CGFloat
  var action: () -> Void

  func body(content: Content) -> some View {
    content
      .scaleEffect(isPressed ? scale : 1)
      .simultaneousGesture(_ButtonGesture(
        action: action,
        pressing: { pressed in
          withAnimation(
            .spring(
              response: 0.3,
              dampingFraction: 0.5,
              blendDuration: 0.3
            )
          ) {
            isPressed = pressed
          }
        }
      ))
  }
}

#Preview {
  SquishyButton {
    print(UUID().uuidString)
  } label: {
    Image(systemName: "play.fill")
      .font(.system(size: 100))
  }
}
