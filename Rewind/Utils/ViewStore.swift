//
//  ViewStore.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 9. 11. 2025.
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
      actionPerformer: reducer.callAsFunction(_:),
    )
  }

  init(
    state: ObservedVariable<State>,
    actionPerformer: @escaping (Action) -> Void,
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

  func bimap<NewState, NewAction>(
    state makeNewState: @escaping (State) -> NewState,
    action makeOldAction: @escaping (NewAction) -> Action,
  ) -> ViewStore<NewState, NewAction> {
    ViewStore<NewState, NewAction>(
      state: state.map(makeNewState),
      actionPerformer: { self(makeOldAction($0)) },
    )
  }

  func bimap<NewState: Equatable, NewAction>(
    state makeNewState: @escaping (State) -> NewState,
    action makeOldAction: @escaping (NewAction) -> Action
  ) -> ViewStore<NewState, NewAction> {
    ViewStore<NewState, NewAction>(
      state: state.map(makeNewState),
      actionPerformer: { self(makeOldAction($0)) },
    )
  }
}

extension ViewStore where State: Equatable {
  func skipRepeats() -> ViewStore<State, Action> {
    ViewStore(
      state: state.ov.skipRepeats().asObservedVariable(),
      actionPerformer: { self($0) }
    )
  }
}

extension ViewStore {
  func binding<T>(
    _ kp: KeyPath<State, T>,
    send: @escaping (T) -> Action,
  ) -> Binding<T> {
    Binding(
      get: { state.wrappedValue[keyPath: kp] },
      set: { newValue in
        self(send(newValue))
      },
    )
  }

  static func merge<S1, A1, S2, A2>(
    _ lhs: ViewStore<S1, A1>,
    _ rhs: ViewStore<S2, A2>,
    stateTransform: @escaping (S1, S2) -> State,
    actionTransform: @escaping (Action) -> Either<A1, A2>,
  ) -> ViewStore<State, Action> {
    ViewStore(
      state: ObservableVariable.combineLatest(
        lhs.state.ov,
        rhs.state.ov
      ).map(stateTransform).asObservedVariable(),
      actionPerformer: { action in
        let decided = actionTransform(action)
        switch decided {
        case let .left(l): lhs(l)
        case let .right(r): rhs(r)
        }
      }
    )
  }

  static func merge<Key: Hashable, S, A>(
    _ stores: [Key: ViewStore<S, A>],
    actionTransform: @escaping (Action) -> (Key, A)
  ) -> ViewStore<State, Action> where State == [Key: S] {
    ViewStore(
      state: ObservableVariable.combineLatest(stores.mapValues(\.state.ov)).asObservedVariable(),
      actionPerformer: { action in
        let (key, storeAction) = actionTransform(action)
        guard let store = stores[key] else {
          assertionFailure()
          return
        }
        store(storeAction)
      }
    )
  }
}

extension Reducer {
  typealias Store = ViewStore<State, Action>

  var viewStore: Store {
    ViewStore(reducer: self)
  }
}
