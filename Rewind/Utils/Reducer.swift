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
  typealias Effect = () -> Void
  struct AsyncEffect {
    var id: String
    var action: ((Action) async -> Void) async -> Void
  }

  @ObservableProperty
  private(set) var state: State
  private let reduce: ActionHandler
  @Property
  private var asyncEffects: [String: (Task<Void, Error>, UUID)]
  private let disposePool = AutodisposePool()
  private var isRunning = false

  typealias ActionHandler = @MainActor (
    inout State,
    Action,
    _ enqueueEffect: (@escaping Effect) -> Void,
    _ enqueueAsyncEffect: (Reducer<State, Action>.AsyncEffect) -> Void,
  ) -> Void

  init(
    initial: State,
    reduce: @escaping ActionHandler,
  ) {
    _state = ObservableProperty(initialValue: initial)
    _asyncEffects = Property(initialValue: [:])
    self.reduce = reduce
  }

  func callAsFunction(_ action: Action) {
    assert(!isRunning, "Calling the same reducer recursively leads to unexpected state changes")
    var newEffects = [Effect]()
    var newAsyncEffects = [AsyncEffect]()

    isRunning = true
    reduce(&state, action, { action in newEffects.append(action) }, { newAsyncEffects.append($0) })
    isRunning = false

    for e in newEffects {
      e()
    }
    for ae in newAsyncEffects {
      asyncEffects[ae.id]?.0.cancel()
      asyncEffects[ae.id] = nil
      let taskID = UUID()
      asyncEffects[ae.id] = (Task { [weak self] in
        await ae.action { action in await MainActor.run { self?(action) } }
        if let self, asyncEffects[ae.id]?.1 == taskID {
          asyncEffects[ae.id] = nil
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
  case filtersChanged
  case unfoldControlsBack

  var delay: TimeInterval {
    switch self {
    case .regionChanged, .filtersChanged, .updatePreviews: 0.1
    case .unfoldControlsBack: 2
    }
  }
}

extension Reducer {
  func adding<Value>(
    signal: Signal<Value>,
    makeAction: @escaping (Value) -> Action,
  ) -> Reducer<State, Action> {
    modified(self) {
      $0.store(disposable: signal.addObserver { [weak self] in
        self?(makeAction($0))
      })
    }
  }

  func onStateUpdate(
    perform: @escaping (State) -> Void,
  ) -> Reducer<State, Action> {
    let disposable = $state.currentAndNewValues.addObserver {
      perform($0)
    }
    return modified(self) {
      $0.store(disposable: disposable)
    }
  }
}

extension Reducer.AsyncEffect {
  static func perform(
    id: String = UUID().uuidString,
    action: @escaping ((Action) async -> Void) async -> Void,
  ) -> Reducer.AsyncEffect {
    Reducer.AsyncEffect(
      id: id,
      action: action,
    )
  }

  static func anotherAction(
    id: String = UUID().uuidString,
    _ action: Action,
  ) -> Reducer.AsyncEffect {
    Reducer.AsyncEffect(
      id: id,
      action: { performAnotherReducerAction in
        await performAnotherReducerAction(action)
      },
    )
  }

  static func after(
    _ delay: TimeInterval,
    id: String = UUID().uuidString,
    anotherAction: Action,
  ) -> Reducer.AsyncEffect {
    Reducer.AsyncEffect(
      id: id,
      action: { performAnotherReducerAction in
        do {
          try await Task.sleep(for: .seconds(delay))
          await performAnotherReducerAction(anotherAction)
        } catch {}
      },
    )
  }

  static func cancel(
    id: String,
  ) -> Reducer.AsyncEffect {
    Reducer.AsyncEffect(
      id: id,
      action: { _ in },
    )
  }

  static func cancel(
    debouncedAction: DebouncedActionID,
  ) -> Reducer.AsyncEffect {
    .cancel(id: debouncedAction.rawValue)
  }

  static func debounced(
    id: DebouncedActionID,
    action: @escaping ((Action) async -> Void) async -> Void,
  ) -> Reducer.AsyncEffect {
    Reducer.AsyncEffect(
      id: id.rawValue,
      action: { performAnotherReducerAction in
        do {
          try await Task.sleep(for: .seconds(id.delay))
          await action(performAnotherReducerAction)
        } catch {}
      },
    )
  }

  static func debounced(
    id: DebouncedActionID,
    anotherAction: Action,
  ) -> Reducer.AsyncEffect {
    Reducer.AsyncEffect(
      id: id.rawValue,
      action: { performAnotherReducerAction in
        do {
          try await Task.sleep(for: .seconds(id.delay))
          await performAnotherReducerAction(anotherAction)
        } catch {}
      },
    )
  }
}
