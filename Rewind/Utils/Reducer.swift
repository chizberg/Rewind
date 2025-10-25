//
//  Reducer.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 03.02.2025.
//

import Foundation

import VGSL

struct Reducer<State, ReducerAction> {
  struct Effect {
    var id: String = UUID().uuidString
    var action: ((ReducerAction) async -> Void) async throws -> Void
  }

  @ObservableProperty
  private(set) var state: State
  private let reduce: Reduce
  @MainActor @Property
  private var effects: [String: Task<Void, Error>]

  typealias Reduce = (
    inout State,
    ReducerAction,
    _ enqueueEffect: (Effect) -> Void
  ) -> Void

  init(
    initial: State,
    reduce: @escaping Reduce
  ) {
    _state = ObservableProperty(initialValue: initial)
    _effects = Property(initialValue: [:])
    self.reduce = reduce
  }

  func callAsFunction(_ action: ReducerAction) {
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

extension Reducer.Effect {
  static func regular(
    action: @escaping ((ReducerAction) async -> Void) async throws -> Void
  ) -> Reducer.Effect {
    Reducer.Effect(
      action: action
    )
  }

  static func throttled(
    id: ThrottledActionID,
    action: @escaping ((ReducerAction) async -> Void) async throws -> Void
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
