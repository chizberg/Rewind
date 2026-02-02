//
//  OnboardingViewModel.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 23. 11. 2025.
//

import Foundation
import VGSL

typealias OnboardingViewModel = Reducer<OnboardingViewState, OnboardingViewAction>

struct OnboardingViewState {}

enum OnboardingViewAction {
  case onboardingFinished
}

struct OnboardingStorage: Codable {
  var wasShown: Bool
}

func makeOnboardingViewModel(
  keyValueStorage: KeyValueStorage,
  onFinish: @escaping Action
) -> OnboardingViewModel? {
  let storage = keyValueStorage.makeCodableField(
    key: "onboarding",
    default: OnboardingStorage(wasShown: false)
  )
  guard !storage.value.wasShown else {
    return nil
  }
  return OnboardingViewModel(onFinish: {
    storage.value.wasShown = true
    onFinish()
  })
}

extension OnboardingViewModel {
  convenience init(
    onFinish: @escaping () -> Void
  ) {
    self.init(
      initial: OnboardingViewState(),
      reduce: { _, action, _ in
        switch action {
        case .onboardingFinished:
          onFinish()
        }
      }
    )
  }
}
