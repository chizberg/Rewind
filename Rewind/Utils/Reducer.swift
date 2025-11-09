//
//  Reducer.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import Foundation

import VGSL

final class Reducer<State, Action> {
  struct Effect {
    var id: String = UUID().uuidString
    var action: ((Action) async -> Void) async throws -> Void
  }

  @ObservableProperty
  private(set) var state: State
  private let reduce: ActionHandler
  @MainActor @Property
  private var effects: [String: Task<Void, Error>]
  private let disposePool = AutodisposePool()

  typealias ActionHandler = (
    inout State,
    Action,
    _ enqueueEffect: (Reducer<State, Action>.Effect) -> Void
  ) -> Void

  init(
    initial: State,
    reduce: @escaping ActionHandler
  ) {
    _state = ObservableProperty(initialValue: initial)
    _effects = Property(initialValue: [:])
    self.reduce = reduce
  }

  func callAsFunction(_ action: Action) {
    var newEffects = [Effect]()
    reduce(&state, action) { newEffects.append($0) }
    for effect in newEffects {
      Task { // TODO: chizberg - simplify?
        await MainActor.run {
          if let existingTask = effects[effect.id] {
            existingTask.cancel()
          }
          effects[effect.id] = Task {
            try await effect.action { action in await MainActor.run { self(action) } }
            effects[effect.id] = nil
          }
        }
      }
    }
  }

  private func store(disposable: Disposable) {
    disposable.dispose(in: disposePool)
  }
}

enum ThrottledActionID: String {
  case regionChanged
  case updatePreviews
  case loadAnnotations
  case clearAnnotations

  var delay: TimeInterval {
    switch self {
    case .regionChanged, .loadAnnotations, .clearAnnotations: 0.15
    case .updatePreviews: 0.3
    }
  }
}

extension Reducer {
  // This bimap does not work with effects, effects cause the states to go out of sync.
  func unsafeBimap<NewState, NewAction>(
    state makeNewState: @escaping (State) -> NewState,
    action makeOldAction: @escaping (NewAction) -> Action
  ) -> Reducer<NewState, NewAction> {
    Reducer<NewState, NewAction>(
      initial: makeNewState(state)
    ) { newState, newAction, _ in
      let oldAction = makeOldAction(newAction)
      self(oldAction)
      newState = makeNewState(self.state)
    }
  }

  func adding<Value>(
    signal: Signal<Value>,
    makeAction: @escaping (Value) -> Action
  ) -> Reducer<State, Action> {
    modified(self) {
      $0.store(disposable: signal.addObserver { [weak self] in
        self?(makeAction($0))
      })
    }
  }
}

extension Reducer.Effect {
  static func regular(
    action: @escaping ((Action) async -> Void) async throws -> Void
  ) -> Reducer.Effect {
    Reducer.Effect(
      action: action
    )
  }

  static func throttled(
    id: ThrottledActionID,
    action: @escaping ((Action) async -> Void) async throws -> Void
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id.rawValue,
      action: { performAnotherReducerAction in
        try await Task.sleep(for: .seconds(id.delay))
        try await action(performAnotherReducerAction)
      }
    )
  }
}
