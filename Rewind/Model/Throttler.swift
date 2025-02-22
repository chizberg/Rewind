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
      throttlers[id] = ThrottledActionPerformer(delay: delay)
    }
    throttlers[id]?.throttledCall { [weak self] in
      self?.throttlers[id] = nil
      action()
    }
  }
}

private class ThrottledActionPerformer {
  private let delay: Double
  private var task: Task<Void, Error>?

  init(
    delay: Double
  ) {
    self.delay = delay
  }

  func throttledCall(action: @escaping () -> Void) {
    task?.cancel()
    task = nil
    task = makeTask(action)
  }

  private func makeTask(_ action: @escaping () -> Void) -> Task<Void, Error> {
    Task {
      try await Task.sleep(for: .seconds(delay))
      try Task.checkCancellation()
      await MainActor.run {
        action()
      }
    }
  }
}
