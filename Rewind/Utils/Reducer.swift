//
//  Reducer.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import Foundation
import VGSL

@preconcurrency @MainActor
final class Reducer<State, Action> {
  struct Effect {
    var id: String
    var action: ((Action) async -> Void) async -> Void
  }

  @ObservableProperty
  private(set) var state: State
  private let reduce: ActionHandler
  @Property
  private var effects: [String: (Task<Void, Error>, UUID)]
  private let disposePool = AutodisposePool()

  typealias ActionHandler = @MainActor (
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
      effects[effect.id]?.0.cancel()
      effects[effect.id] = nil
      let taskID = UUID()
      effects[effect.id] = (Task { [weak self] in
        await effect.action { action in await MainActor.run { self?(action) } }
        if let self, effects[effect.id]?.1 == taskID {
          effects[effect.id] = nil
        }
      }, taskID)
    }
  }

  private func store(disposable: Disposable) {
    disposable.dispose(in: disposePool)
  }
}

enum DebouncedActionID: String {
  case regionChanged
  case updatePreviews
  case yearRangeChanged
  case unfoldControlsBack

  var delay: TimeInterval {
    switch self {
    case .regionChanged, .yearRangeChanged, .updatePreviews: 0.1
    case .unfoldControlsBack: 2
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

  func onStateUpdate(
    perform: @escaping (State) -> Void
  ) -> Reducer<State, Action> {
    let disposable = $state.currentAndNewValues.addObserver {
      perform($0)
    }
    return modified(self) {
      $0.store(disposable: disposable)
    }
  }
}

extension Reducer.Effect {
  static func perform(
    id: String = UUID().uuidString,
    action: @escaping ((Action) async -> Void) async -> Void
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id,
      action: action
    )
  }

  static func anotherAction(
    id: String = UUID().uuidString,
    _ action: Action
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id,
      action: { performAnotherReducerAction in
        await performAnotherReducerAction(action)
      }
    )
  }

  static func after(
    _ delay: TimeInterval,
    id: String = UUID().uuidString,
    anotherAction: Action
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id,
      action: { performAnotherReducerAction in
        do {
          try await Task.sleep(for: .seconds(delay))
          await performAnotherReducerAction(anotherAction)
        } catch {}
      }
    )
  }

  static func cancel(
    id: String
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id,
      action: { _ in }
    )
  }

  static func cancel(
    debouncedAction: DebouncedActionID
  ) -> Reducer.Effect {
    .cancel(id: debouncedAction.rawValue)
  }

  static func debounced(
    id: DebouncedActionID,
    action: @escaping ((Action) async -> Void) async -> Void
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id.rawValue,
      action: { performAnotherReducerAction in
        do {
          try await Task.sleep(for: .seconds(id.delay))
          await action(performAnotherReducerAction)
        } catch {}
      }
    )
  }

  static func debounced(
    id: DebouncedActionID,
    anotherAction: Action
  ) -> Reducer.Effect {
    Reducer.Effect(
      id: id.rawValue,
      action: { performAnotherReducerAction in
        do {
          try await Task.sleep(for: .seconds(id.delay))
          await performAnotherReducerAction(anotherAction)
        } catch {}
      }
    )
  }
}
