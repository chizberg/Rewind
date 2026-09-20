//
//  BlinkingModifier.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 20. 9. 2026.
//

import SwiftUI

struct BlinkingModifier<T: Equatable>: ViewModifier {
  var trigger: T

  enum Phase: CaseIterable {
    case initial
    case shutterDown
    case shutterUp

    var shutterOpacity: CGFloat {
      switch self {
      case .initial, .shutterUp: 0
      case .shutterDown: 1
      }
    }
  }

  func body(content: Content) -> some View {
    content
      .phaseAnimator(
        Phase.allCases,
        trigger: trigger,
        content: { content, currentPhase in
          content
            .overlay {
              Color.black.opacity(currentPhase.shutterOpacity)
            }
        },
        animation: { nextPhase in
          switch nextPhase {
          case .initial: nil
          case .shutterDown: nil
          case .shutterUp: .easeInOut(duration: 0.25)
          }
        },
      )
  }
}
