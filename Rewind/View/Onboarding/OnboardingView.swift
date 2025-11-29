//
//  OnboardingView.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 11. 2025..
//

import SwiftUI

struct OnboardingView: View {
  enum Screen {
    case annotations
  }

  @State
  var path: [Screen] = []

  var store: OnboardingViewModel.Store

  var body: some View {
    NavigationStack(path: $path) {
      WelcomeScreen(
        goNext: { path.append(.annotations) }
      ).navigationDestination(for: Screen.self) { screen in
        switch screen {
        case .annotations:
          AnnotationsScreen(goNext: { store(.onboardingFinished) })
        }
      }
    }
  }
}

let rewindRed = Color.fromHex(0xB2_3C_36_FF)

extension Button {
  @ViewBuilder
  func prominent() -> some View {
    if #available(iOS 26, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }
}

extension View {
  func onboardingCard() -> some View {
    padding()
      .background(Color.secondarySystemBackground)
      .cornerRadius(25)
  }
}

#if DEBUG
#Preview {
  @Previewable @State
  var store = OnboardingViewModel(onFinish: {}).viewStore

  OnboardingView(store: store)
}

#Preview("ru") {
  @Previewable @State
  var store = OnboardingViewModel(onFinish: {}).viewStore

  OnboardingView(store: store)
    .environment(\.locale, .init(identifier: "ru"))
}
#endif
