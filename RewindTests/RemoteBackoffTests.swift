//
//  RemoteBackoffTests.swift
//  RewindTests
//
//  Behavioural tests for Remote.exponentialBackoff: it retries a failing call up
//  to `attemptCount` times and returns the first success, and cancelling the
//  surrounding Task aborts the pending retry (on iOS this falls out of Task.sleep
//  throwing, which is exactly the invariant pinned here so a port can't regress it).
//  Delay *durations* are not asserted here — there is no virtual clock; the Android
//  mirror pins the exact 1s/2s schedule under kotlinx test time.
//

import Foundation
@testable import Rewind
import Testing

private actor Counter {
  var n = 0
  func bump() { n += 1 }
}

struct RemoteBackoffTests {
  @Test func retriesUntilSuccess() async throws {
    let counter = Counter()
    // Fails on attempts 1 and 2, succeeds on attempt 3.
    let remote = Remote<Void, Int> { _ in
      await counter.bump()
      if await counter.n < 3 {
        throw HandlingError("attempt failed")
      }
      return 42
    }.exponentialBackoff(initialDelay: 0.01)

    let result = try await remote.load(())
    #expect(result == 42)
    #expect(await counter.n == 3)
  }

  @Test func cancellationDuringBackoffAbortsRetries() async throws {
    let counter = Counter()
    let remote = Remote<Void, Int> { _ in
      await counter.bump()
      throw HandlingError("always fails")
    }.exponentialBackoff(initialDelay: 0.3)

    let task = Task { try await remote.load(()) }
    // Wait until the first attempt has run; the Task is now sleeping before its retry.
    while await counter.n < 1 {
      await Task.yield()
    }
    task.cancel()
    // Well past the retry delay: the cancelled sleep must have aborted the second attempt.
    try await Task.sleep(for: .milliseconds(500))
    #expect(await counter.n == 1)
    _ = try? await task.value
  }
}
