//
//  ReducerTests.swift
//  RewindTests
//
//  Unit tests for the generic Reducer / ViewStore state-management primitive.
//

@testable import Rewind
import Testing
import VGSL

// MARK: - Test fixtures

private struct TestState: Equatable {
  var count = 0
  var applied: [String] = []
}

private typealias TestReducer = Reducer<TestState, TestAction>
private typealias TestEffect = Reducer<TestState, TestAction>.Effect // () -> Void
private typealias TestAsyncEffect = Reducer<TestState, TestAction>.AsyncEffect

private enum TestAction {
  case increment
  case add(Int)
  case mark(String)
  /// Enqueue synchronous effects (run right after reduce, on the calling stack).
  case syncEffects([TestEffect])
  /// Enqueue asynchronous effects (run later, each in its own cancellable Task).
  case asyncEffects([TestAsyncEffect])
  /// Enqueue both kinds in a single reduce, to test their relative ordering.
  case mixed(sync: [TestEffect], async: [TestAsyncEffect])
}

@MainActor
private func makeReducer(initial: TestState = .init()) -> TestReducer {
  Reducer(initial: initial) { state, action, effect, asyncEffect in
    switch action {
    case .increment:
      state.count += 1
    case let .add(value):
      state.count += value
    case let .mark(tag):
      state.applied.append(tag)
    case let .syncEffects(effects):
      for e in effects {
        effect(e)
      }
    case let .asyncEffects(effects):
      for ae in effects {
        asyncEffect(ae)
      }
    case let .mixed(sync, async):
      for e in sync {
        effect(e)
      }
      for ae in async {
        asyncEffect(ae)
      }
    }
  }
}

// MARK: - Async helpers

/// Polls `condition` until it becomes true or the timeout elapses.
/// Needed because async effects run inside an internal `Task` we can't await directly.
@MainActor
private func eventually(
  timeout: Duration = .seconds(2),
  _ condition: () -> Bool,
) async -> Bool {
  let deadline = ContinuousClock().now.advanced(by: timeout)
  while !condition() {
    if ContinuousClock().now >= deadline { return false }
    try? await Task.sleep(for: .milliseconds(5))
  }
  return true
}

private func sleep(_ duration: Duration) async {
  try? await Task.sleep(for: duration)
}

// MARK: - Synchronous state mutation

@MainActor
struct ReducerSyncTests {
  @Test func singleActionMutatesState() {
    let reducer = makeReducer()
    reducer(.increment)
    #expect(reducer.state.count == 1)
  }

  @Test func multipleActionsAccumulate() {
    let reducer = makeReducer()
    reducer(.increment)
    reducer(.increment)
    reducer(.increment)
    reducer(.add(2))
    #expect(reducer.state.count == 5)
  }

  @Test func mutationIsSynchronous() {
    let reducer = makeReducer()
    reducer(.mark("a"))
    reducer(.mark("b"))
    #expect(reducer.state.applied == ["a", "b"])
  }
}

// MARK: - Synchronous effects

@MainActor
struct ReducerSyncEffectTests {
  @Test func syncEffectRunsImmediatelyAfterReduce() {
    let reducer = makeReducer()
    var ran = false
    // Synchronous effects run on the calling stack — no Task, no await.
    reducer(.syncEffects([{ ran = true }]))
    #expect(ran)
  }

  @Test func syncEffectsRunInEnqueueOrder() {
    let reducer = makeReducer()
    var log: [Int] = []
    reducer(.syncEffects([
      { log.append(1) },
      { log.append(2) },
      { log.append(3) },
    ]))
    #expect(log == [1, 2, 3])
  }

  @Test func syncEffectMaySafelyDispatchFollowUpAction() {
    // Sync effects run after the reducer clears its `isRunning` guard, so
    // re-entering the same reducer from a sync effect is allowed (synchronous,
    // no Task hop) and does not trip the recursion assertion.
    let reducer = makeReducer()
    reducer(.syncEffects([{ reducer(.add(5)) }]))
    #expect(reducer.state.count == 5)
  }

  @Test func syncEffectsRunBeforeAsyncEffectsAreScheduled() async {
    // The headline invariant of the dual-effect model: within ONE reduce call,
    // every synchronous effect runs (on the calling stack) before any async
    // effect is scheduled.
    let reducer = makeReducer()
    reducer(.mixed(
      sync: [{ reducer(.mark("sync")) }],
      async: [.anotherAction(.mark("async"))],
    ))
    // Sync effect has already run; the async effect is only scheduled, not run.
    #expect(reducer.state.applied == ["sync"])
    #expect(await eventually { reducer.state.applied == ["sync", "async"] })
  }
}

// MARK: - Asynchronous effects

@MainActor
struct ReducerAsyncEffectTests {
  @Test func multipleEffectsPerActionAllRun() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([
      .anotherAction(id: "a", .increment),
      .anotherAction(id: "b", .increment),
    ]))
    #expect(await eventually { reducer.state.count == 2 })
  }

  @Test func performEffectDispatchesFollowUp() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([
      .perform(id: "p") { send in
        await send(.add(7))
      },
    ]))
    #expect(await eventually { reducer.state.count == 7 })
  }

  @Test func anotherActionEffectDispatchesFollowUp() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([.anotherAction(id: "x", .increment)]))
    #expect(await eventually { reducer.state.count == 1 })
  }

  @Test func afterEffectFiresAfterDelay() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([.after(0.05, id: "t", anotherAction: .increment)]))
    #expect(reducer.state.count == 0) // not yet
    #expect(await eventually { reducer.state.count == 1 })
  }
}

// MARK: - Cancellation / deduplication by effect id

@MainActor
struct ReducerCancellationTests {
  @Test func sameIdReplacesPendingEffect() async {
    let reducer = makeReducer()
    // First effect would add 10 after a long delay...
    reducer(.asyncEffects([.after(0.3, id: "x", anotherAction: .add(10))]))
    // ...but a second effect with the same id supersedes it.
    reducer(.asyncEffects([.after(0.05, id: "x", anotherAction: .add(1))]))

    #expect(await eventually { reducer.state.count == 1 })
    // Wait past the first effect's original delay to confirm it never fires.
    await sleep(.milliseconds(400))
    #expect(reducer.state.count == 1)
  }

  @Test func cancelEffectStopsPendingFollowUp() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([.after(0.2, id: "x", anotherAction: .add(10))]))
    reducer(.asyncEffects([.cancel(id: "x")]))

    await sleep(.milliseconds(350))
    #expect(reducer.state.count == 0)
  }

  @Test func differentIdsRunIndependently() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([
      .after(0.05, id: "a", anotherAction: .increment),
      .after(0.05, id: "b", anotherAction: .increment),
    ]))
    #expect(await eventually { reducer.state.count == 2 })
  }

  @Test func effectIdCanBeReusedAfterCancel() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([.after(0.2, id: "x", anotherAction: .add(10))]))
    reducer(.asyncEffects([.cancel(id: "x")]))
    // Re-arm the same id with a fresh effect; it should fire exactly once.
    reducer(.asyncEffects([.after(0.05, id: "x", anotherAction: .increment)]))

    #expect(await eventually { reducer.state.count == 1 })
    await sleep(.milliseconds(300))
    #expect(reducer.state.count == 1) // the cancelled add(10) never fires
  }
}

// MARK: - Debounce

@MainActor
struct ReducerDebounceTests {
  @Test func debouncedCollapsesRapidDispatches() async {
    let reducer = makeReducer()
    // Five rapid debounced dispatches share one id → only the last survives.
    for _ in 0..<5 {
      reducer(.asyncEffects([.debounced(id: .regionChanged, anotherAction: .increment)]))
    }
    #expect(await eventually { reducer.state.count == 1 })
    await sleep(.milliseconds(250)) // ≥2× the 100ms debounce: confirm no extra fire
    #expect(reducer.state.count == 1)
  }

  @Test func debouncedClosureFormRunsAfterDelay() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([.debounced(id: .regionChanged) { send in
      await send(.add(3))
    }]))
    #expect(reducer.state.count == 0) // debounce delay not elapsed yet
    #expect(await eventually { reducer.state.count == 3 })
  }

  @Test func cancelDebouncedStopsPendingFollowUp() async {
    let reducer = makeReducer()
    reducer(.asyncEffects([.debounced(id: .regionChanged, anotherAction: .add(10))]))
    reducer(.asyncEffects([.cancel(debouncedAction: .regionChanged)]))

    await sleep(.milliseconds(200))
    #expect(reducer.state.count == 0)
  }

  @Test func debouncedActionIdDelays() {
    #expect(DebouncedActionID.regionChanged.delay == 0.1)
    #expect(DebouncedActionID.updatePreviews.delay == 0.1)
    #expect(DebouncedActionID.filtersChanged.delay == 0.1)
    #expect(DebouncedActionID.unfoldControlsBack.delay == 2)
  }
}

// MARK: - Reducer extensions

@MainActor
struct ReducerExtensionTests {
  @Test func onStateUpdateReceivesCurrentAndNewValues() {
    var observed: [Int] = []
    let reducer = makeReducer().onStateUpdate { observed.append($0.count) }
    reducer(.increment)
    reducer(.increment)
    // Observer fires immediately with the current value, then on every change.
    #expect(observed == [0, 1, 2])
  }

  @Test func addingSignalDispatchesAction() {
    let pipe = SignalPipe<Int>()
    let reducer = makeReducer().adding(signal: pipe.signal) { .add($0) }
    pipe.send(5)
    #expect(reducer.state.count == 5)
  }
}

// MARK: - ViewStore

@MainActor
struct ViewStoreTests {
  @Test func readsStateViaDynamicMember() {
    let store = makeReducer(initial: TestState(count: 42)).viewStore
    #expect(store.count == 42)
  }

  @Test func dispatchesActionsAndReflectsState() {
    let store = makeReducer().viewStore
    store(.increment)
    store(.add(4))
    #expect(store.count == 5)
  }

  @Test func bimapMapsStateAndAction() {
    let store = makeReducer().viewStore
    let mapped = store.bimap(
      state: { $0.count },
      action: { (value: Int) in TestAction.add(value) },
    )
    mapped(6)
    #expect(mapped.state.wrappedValue == 6)
  }
}
