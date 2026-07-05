//
//  ObservableVariable+CombineLatest.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 5. 7. 2026.
//

import VGSL

extension ObservableVariable {
  /// Combines two observable variables into one holding their latest values as a tuple.
  ///
  /// Unlike `Signal.combineLatest`, both sources already carry a current value, so the result
  /// has a value immediately (no waiting for every source to emit) and emits a fresh tuple
  /// whenever either source changes, pairing the new value with the other source's latest value.
  static func combineLatest<A, B>(
    _ a: ObservableVariable<A>,
    _ b: ObservableVariable<B>
  ) -> ObservableVariable where T == (A, B) {
    ObservableVariable(
      initialValue: (a.value, b.value),
      newValues: .merge(
        a.newValues.map { ($0, b.value) },
        b.newValues.map { (a.value, $0) }
      )
    )
  }

  static func combineLatest<A, B, C>(
    _ a: ObservableVariable<A>,
    _ b: ObservableVariable<B>,
    _ c: ObservableVariable<C>
  ) -> ObservableVariable where T == (A, B, C) { // swiftlint:disable:this large_tuple
    ObservableVariable(
      initialValue: (a.value, b.value, c.value),
      newValues: .merge(
        a.newValues.map { ($0, b.value, c.value) },
        b.newValues.map { (a.value, $0, c.value) },
        c.newValues.map { (a.value, b.value, $0) }
      )
    )
  }
}
