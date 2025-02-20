//
//  Throttler.swift
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
    case .internal(.loadAnnotations):
      throttledCall(
        id: "loadAnnotations",
        action: { perform(action) },
        delay: 0.15
      )
    case .internal(.clearAnnotations):
      throttledCall(
        id: "clearAnnotations",
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

private class ThrottledActionPerformer {
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

  func throttledCall() {
    task?.cancel()
    task = nil
    task = makeTask()
  }

  private func makeTask() -> Task<Void, Error> {
    Task {
      try await Task.sleep(for: .seconds(delay))
      try Task.checkCancellation()
      await MainActor.run {
        action()
      }
    }
  }
}
