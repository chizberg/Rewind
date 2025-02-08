//
//  Reducer.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import VGSL

struct Reducer<State, Action> {
  @ObservableProperty
  private(set) var state: State
  private let reduce: (
    inout State,
    Action,
    (Action) -> Void,
    (@escaping () async throws -> Action) -> Void
  ) -> Void

  init(
    initial: State,
    reduce: @escaping (
      inout State,
      Action,
      (Action) -> Void,
      (@escaping () async throws -> Action) -> Void
    ) -> Void
  ) {
    _state = ObservableProperty(initialValue: initial)
    self.reduce = reduce
  }

  func callAsFunction(_ action: Action) {
    var effects = [Action]()
    var loadableEffects = [() async throws -> Action]()
    reduce(&state, action, { effects.append($0) }, { loadableEffects.append($0) })
    effects.forEach { self($0) }
    for loadEffect in loadableEffects {
      Task {
        let action = try await loadEffect()
        await MainActor.run {
          self(action)
        }
      }
    }
  }
}
