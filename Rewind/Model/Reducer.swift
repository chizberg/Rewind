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
  private let reduce: (inout State, Action, (Action) -> Void) -> Void

  init(
    initial: State,
    reduce: @escaping (inout State, Action, (Action) -> Void) -> Void
  ) {
    _state = ObservableProperty(initialValue: initial)
    self.reduce = reduce
  }

  func callAsFunction(_ action: Action) {
    var effects = [Action]()
    reduce(&state, action, { effects.append($0) })
    effects.forEach { self($0) }
  }
}
