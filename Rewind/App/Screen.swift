//
//  Screen.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 20. 9. 2026..
//

import SwiftUI

struct Screen: Hashable {
  enum Value {
    case image(ImageDetailsModel.Store)
    case list(ImageListModel.Store)
    case onboarding(OnboardingViewModel.Store)
    case comparison(ComparisonViewDeps)
    case fullscreenPreview(FullscreenPreviewStore)
  }

  enum Kind {
    case image
    case list
    case onboarding
    case comparison
    case fullscreenPreview
  }

  let value: Value
  let id: UUID

  init(_ value: Value, id: UUID = UUID()) {
    self.value = value
    self.id = id
  }

  static func ==(lhs: Screen, rhs: Screen) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  func view(
    namespace: Namespace.ID
  ) -> some View {
    view()
      .ifLet(transitionSource) { view, source in
        view.zoomed(from: source, namespace: namespace)
      }
  }

  @ViewBuilder
  private func view() -> some View {
    switch value {
    case let .image(store):
      ImageDetailsView(viewStore: store)
    case let .list(store):
      ImageList(viewStore: store)
    case let .onboarding(store):
      OnboardingView(store: store)
    case let .comparison(deps):
      ComparisonScreen(deps: deps)
    case let .fullscreenPreview(store):
      FullscreenPreview(store: store)
    }
  }

  var kind: Kind {
    switch value {
    case .image: .image
    case .list: .list
    case .onboarding: .onboarding
    case .comparison: .comparison
    case .fullscreenPreview: .fullscreenPreview
    }
  }

  var transitionSource: TransitionSource? {
    switch value {
    case let .image(store): store.source
    case let .list(store): store.source
    case let .onboarding(store): nil
    case let .comparison(deps): deps.store.source
    case let .fullscreenPreview(store): store.source
    }
  }
}
