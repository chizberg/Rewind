import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/chizberg/Documents/Личные проекты/Rewind/Rewind/Utils/SquishyButton.swift", line: 1)
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
          scale: __designTimeFloat("#21226_0", fallback: 0.9),
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
      .scaleEffect(isPressed ? scale : __designTimeInteger("#21226_1", fallback: 1))
      .simultaneousGesture(_ButtonGesture(
        action: action,
        pressing: { pressed in
          withAnimation(
            .spring(
              response: __designTimeFloat("#21226_2", fallback: 0.3),
              dampingFraction: __designTimeFloat("#21226_3", fallback: 0.3),
              blendDuration: __designTimeFloat("#21226_4", fallback: 0.1)
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
    Image(systemName: __designTimeString("#21226_5", fallback: "play.fill"))
      .font(.system(size: __designTimeInteger("#21226_6", fallback: 100)))
  }
}
