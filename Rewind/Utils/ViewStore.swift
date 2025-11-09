//
//  ViewStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025..
//

import Foundation
import SwiftUI

import VGSL

@dynamicMemberLookup
struct ViewStore<State, Action> {
  var state: ObservedVariable<State>

  private var actionPerformer: (Action) -> Void

  init(reducer: Reducer<State, Action>) {
    self.init(
      state: reducer.$state.asObservedVariable(),
      actionPerformer: reducer.callAsFunction(_:)
    )
  }

  init(
    state: ObservedVariable<State>,
    actionPerformer: @escaping (Action) -> Void
  ) {
    self.state = state
    self.actionPerformer = actionPerformer
  }

  func callAsFunction(_ action: Action) {
    actionPerformer(action)
  }

  subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
    state.wrappedValue[keyPath: keyPath]
  }
}

extension Reducer {
  var viewStore: ViewStore<State, Action> {
    ViewStore(reducer: self)
  }
}
