//
//  SavedBanner.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 7. 2026.
//

import SwiftUI

struct SavedBanner: View {
  var savesCount: Int

  var body: some View {
    HStack {
      Image(systemName: "photo.badge.checkmark")
      Text("Saved to Photos")
    }
    .padding()
    .blurBackground(in: Capsule())
    .padding(.top, 5)
    .modifier(AnimatedTopBanner(trigger: savesCount))
  }
}

private struct AnimatedTopBanner<T: Equatable>: ViewModifier {
  var trigger: T

  enum Phase: CaseIterable {
    case initial
    case shown
    case pause
    case hidden

    var yOffset: CGFloat {
      switch self {
      case .initial, .hidden: -200
      case .shown: 0
      case .pause: -5 // 🐞 if values are the same, they get ignored
      }
    }

    var opacity: CGFloat {
      switch self {
      case .initial, .hidden: 0
      case .shown, .pause: 1
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
            .offset(y: currentPhase.yOffset)
            .opacity(currentPhase.opacity)
        },
        animation: { nextPhase in
          switch nextPhase {
          case .initial: nil
          case .shown: .smooth
          case .pause: .smooth(duration: 2)
          case .hidden: .smooth
          }
        },
      )
  }
}

#if DEBUG
#Preview("saved banner") {
  @Previewable @State
  var savesCount = 0

  ZStack {
    Image(.cat).resizable().ignoresSafeArea()

    VStack {
      SavedBanner(savesCount: savesCount)
      Spacer()
      Button("Simulate save") {
        savesCount += 1
      }.buttonStyle(.borderedProminent)
    }
  }
}
#endif
