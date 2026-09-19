//
//  Job.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 6. 9. 2026.
//

import VGSL

struct Job<Progress, Success> {
  enum State {
    case running(Progress)
    case finished(Result<Success, Error>)
  }

  let state: ObservableVariable<State>
  let cancel: () -> Void
}

extension Job {
  var states: AsyncStream<State> {
    AsyncStream { continuation in
      var subscription: Disposable?
      subscription = state.currentAndNewValues.addObserver { jobState in
        continuation.yield(jobState)
        if case .finished = jobState {
          continuation.finish()
          subscription?.dispose()
        }
      }
      continuation.onTermination = { _ in cancel() }
    }
  }
}

extension Job where Success: Sendable {
  var value: Success {
    get async throws {
      let finished = state.currentAndNewValues
        .compactMap { state -> Result<Success, Error>? in
          if case let .finished(result) = state { result } else { nil }
        }
        .firstAsFuture()
      return try await withTaskCancellationHandler {
        try await finished.value.get()
      } onCancel: {
        cancel()
      }
    }
  }
}
