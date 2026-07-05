//
//  ObservableVariableCombineLatestTests.swift
//  RewindTests
//
//  Unit tests for ObservableVariable.combineLatest.
//

@testable import Rewind
import Testing
import VGSL

// MARK: - Helpers

/// Collects every value emitted by an observable variable's `newValues`,
/// keeping the subscription alive for the collector's lifetime.
private final class Recorder<T> {
  private(set) var values: [T] = []
  private var subscription: Disposable?

  init(_ ov: ObservableVariable<T>) {
    subscription = ov.newValues.addObserver { [weak self] in
      self?.values.append($0)
    }
  }
}

// MARK: - Binary combineLatest

struct ObservableVariableCombineLatestBinaryTests {
  @Test func initialValueCombinesCurrentValues() {
    let a = ObservableProperty(initialValue: 1)
    let b = ObservableProperty(initialValue: "x")
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    #expect(combined.value == (1, "x"))
  }

  @Test func hasValueImmediatelyWithoutAnyEmission() {
    // Unlike Signal.combineLatest, the variable must already hold a value
    // even though neither source has emitted a new value yet.
    let a = ObservableProperty(initialValue: 10)
    let b = ObservableProperty(initialValue: 20)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    #expect(combined.value == (10, 20))
  }

  @Test func updatingFirstSourceEmitsAndUpdatesValue() {
    let a = ObservableProperty(initialValue: 1)
    let b = ObservableProperty(initialValue: 2)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    let recorder = Recorder(combined)

    a.value = 5
    #expect(combined.value == (5, 2))
    #expect(recorder.values.map { [$0.0, $0.1] } == [[5, 2]])
  }

  @Test func updatingSecondSourceEmitsAndUpdatesValue() {
    let a = ObservableProperty(initialValue: 1)
    let b = ObservableProperty(initialValue: 2)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    let recorder = Recorder(combined)

    b.value = 9
    #expect(combined.value == (1, 9))
    #expect(recorder.values.map { [$0.0, $0.1] } == [[1, 9]])
  }

  @Test func interleavedUpdatesTrackLatestOfBoth() {
    let a = ObservableProperty(initialValue: 0)
    let b = ObservableProperty(initialValue: 0)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    let recorder = Recorder(combined)

    a.value = 1
    b.value = 2
    a.value = 3

    #expect(combined.value == (3, 2))
    #expect(recorder.values.map { [$0.0, $0.1] } == [[1, 0], [1, 2], [3, 2]])
  }

  @Test func emitsOncePerSourceUpdate() {
    let a = ObservableProperty(initialValue: 0)
    let b = ObservableProperty(initialValue: 0)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    let recorder = Recorder(combined)

    a.value = 1
    a.value = 2
    b.value = 3

    #expect(recorder.values.count == 3)
  }

  @Test func doesNotEmitBeforeAnySourceChanges() {
    let a = ObservableProperty(initialValue: 1)
    let b = ObservableProperty(initialValue: 2)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    let recorder = Recorder(combined)
    // `newValues` only fires on subsequent changes, never for the initial value.
    #expect(recorder.values.isEmpty)
  }

  @Test func multipleObserversAllReceiveUpdates() {
    let a = ObservableProperty(initialValue: 0)
    let b = ObservableProperty(initialValue: 0)
    let combined = ObservableVariable.combineLatest(a.projectedValue, b.projectedValue)
    let first = Recorder(combined)
    let second = Recorder(combined)

    a.value = 7

    #expect(first.values.map { [$0.0, $0.1] } == [[7, 0]])
    #expect(second.values.map { [$0.0, $0.1] } == [[7, 0]])
  }

  @Test func mapOnCombinedProducesDerivedValues() {
    let a = ObservableProperty(initialValue: 2)
    let b = ObservableProperty(initialValue: 3)
    let sum = ObservableVariable
      .combineLatest(a.projectedValue, b.projectedValue)
      .map { $0 + $1 }
    let recorder = Recorder(sum)

    #expect(sum.value == 5)
    a.value = 10
    #expect(sum.value == 13)
    #expect(recorder.values == [13])
  }

  @Test func combinesHeterogeneousTypes() {
    let flag = ObservableProperty(initialValue: false)
    let text = ObservableProperty(initialValue: "a")
    let combined = ObservableVariable.combineLatest(flag.projectedValue, text.projectedValue)

    #expect(combined.value == (false, "a"))
    flag.value = true
    #expect(combined.value == (true, "a"))
    text.value = "b"
    #expect(combined.value == (true, "b"))
  }
}

// MARK: - Ternary combineLatest

struct ObservableVariableCombineLatestTernaryTests {
  @Test func initialValueCombinesAllThree() {
    let a = ObservableProperty(initialValue: 1)
    let b = ObservableProperty(initialValue: "x")
    let c = ObservableProperty(initialValue: true)
    let combined = ObservableVariable.combineLatest(
      a.projectedValue, b.projectedValue, c.projectedValue
    )
    #expect(combined.value == (1, "x", true))
  }

  @Test func eachSourceUpdatesIndependently() {
    let a = ObservableProperty(initialValue: 0)
    let b = ObservableProperty(initialValue: 0)
    let c = ObservableProperty(initialValue: 0)
    let combined = ObservableVariable.combineLatest(
      a.projectedValue, b.projectedValue, c.projectedValue
    )
    let recorder = Recorder(combined)

    a.value = 1
    #expect(combined.value == (1, 0, 0))
    b.value = 2
    #expect(combined.value == (1, 2, 0))
    c.value = 3
    #expect(combined.value == (1, 2, 3))

    #expect(recorder.values.map { [$0.0, $0.1, $0.2] } == [[1, 0, 0], [1, 2, 0], [1, 2, 3]])
  }
}
