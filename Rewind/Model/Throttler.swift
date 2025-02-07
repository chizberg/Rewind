//
//  ThrottledActionPerformer.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import Foundation

import VGSL

final class Throttler {
  private var throttlers = [String: ThrottledActionPerformer]()

  func throttle(_ action: MapAction, perform: @escaping (MapAction) -> Void) {
    switch action {
    case .internal(.regionChanged):
      throttledCall(
        id: "regionChanged",
        action: { perform(action) },
        delay: 0.15
      )
    case .internal(.updatePreviews):
      throttledCall(
        id: "updatePreviews",
        action: { perform(action) },
        delay: 0.3
      )
    default:
      assertionFailure("Unsupported action")
    }
  }

  private func throttledCall(
    id: String,
    action: @escaping Action,
    delay: TimeInterval
  ) {
    if throttlers[id] == nil {
      throttlers[id] = ThrottledActionPerformer(delay: delay, action: { [weak self] in
        self?.throttlers[id] = nil
        action()
      })
    }
    throttlers[id]?.throttledCall()
  }
}

private struct ThrottledActionPerformer {
  private var delay: Double
  private let action: Action
  private var task: Task<Void, Error>?

  init(
    delay: Double,
    action: @escaping Action
  ) {
    self.delay = delay
    self.action = action
  }

  mutating func throttledCall() {
    task = nil
    task?.cancel()
    task = makeTask()
  }

  private func makeTask() -> Task<Void, Error> {
    Task {
      try await Task.sleep(for: .seconds(delay))
      await MainActor.run {
        action()
      }
    }
  }
}
