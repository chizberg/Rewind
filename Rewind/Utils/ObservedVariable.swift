//
//  ObservedVariable.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 04.02.2025.
//

import SwiftUI
import VGSL

@propertyWrapper @dynamicMemberLookup
@Observable final class ObservedVariable<Value> {
  private(set) var wrappedValue: Value
  private var subscription: Disposable?
  private let impl: ObservableVariable<Value>

  init(ov: ObservableVariable<Value>) {
    wrappedValue = ov.value
    impl = ov

    subscription = ov.newValues.addObserver { [weak self] in
      self?.wrappedValue = $0
    }
  }

  subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
    wrappedValue[keyPath: keyPath]
  }

  func map<U>(_ transform: @escaping (Value) -> U) -> ObservedVariable<U> {
    impl.map(transform).asObservedVariable()
  }
}

extension ObservableVariable {
  func asObservedVariable() -> ObservedVariable<T> {
    ObservedVariable(ov: self)
  }
}
