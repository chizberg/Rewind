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

struct SquishyButton<Content: View>: View {
  var scale: CGFloat = 0.9
  var action: () -> Void
  var label: (Bool) -> Content

  @State
  private var isPressed = false

  var body: some View {
    label(isPressed)
      .scaleEffect(isPressed ? scale : __designTimeInteger("#21226_0", fallback: 1))
      .gesture(
        _ButtonGesture(
          action: action,
          pressing: { _ in } // does not react as fast as DragGesture
        )
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: __designTimeInteger("#21226_1", fallback: 0))
          .onChanged { _ in
            isPressed = __designTimeBoolean("#21226_2", fallback: true)
          }
          .onEnded { _ in
            isPressed = __designTimeBoolean("#21226_3", fallback: false)
          }
      )
      .animation(
        .spring(
          response: __designTimeFloat("#21226_4", fallback: 0.3),
          dampingFraction: __designTimeFloat("#21226_5", fallback: 0.7),
          blendDuration: __designTimeFloat("#21226_6", fallback: 0.3)
        ),
        value: isPressed
      )
  }
}

#Preview {
  SquishyButton {
    print(UUID().uuidString)
  } label: { pressed in
    Image(systemName: pressed ? __designTimeString("#21226_7", fallback: "play.fill") : __designTimeString("#21226_8", fallback: "play"))
      .font(.system(size: __designTimeInteger("#21226_9", fallback: 100)))
  }
}
