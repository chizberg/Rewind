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

  init(ov: ObservableVariable<Value>) {
    wrappedValue = ov.value

    subscription = ov.newValues.addObserver { [weak self] in
      self?.wrappedValue = $0
    }
  }

  subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
    wrappedValue[keyPath: keyPath]
  }
}

extension ObservableVariable {
  func asObservedVariable() -> ObservedVariable<T> {
    ObservedVariable(ov: self)
  }
}
