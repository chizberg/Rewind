//
//  AsyncTestSupport.swift
//  RewindTests
//
//  Polling helpers shared by the model tests: async effects run inside a Task the tests can't
//  await, so state is observed by polling instead. The timeout is deliberately generous — CI
//  runners are shared and can starve the main actor for seconds at a stretch, which a tight
//  timeout reports as a failed assertion rather than as the scheduling hiccup it is. Polling
//  returns the moment the condition holds, so the slack costs nothing on the passing path.
//

import Foundation

@MainActor
func eventually(
  timeout: Duration = .seconds(30),
  _ condition: () -> Bool,
) async -> Bool {
  let deadline = ContinuousClock().now.advanced(by: timeout)
  while !condition() {
    if ContinuousClock().now >= deadline { return false }
    try? await Task.sleep(for: .milliseconds(5))
  }
  return true
}

/// Grace period for the "and then nothing else happens" half of a cancellation test. Only ever
/// makes such a test slower under load, never wrong: a cancelled effect stays cancelled.
func sleep(_ duration: Duration) async {
  try? await Task.sleep(for: duration)
}
