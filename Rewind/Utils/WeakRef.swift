//
//  WeakRef.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17. 12. 2025..
//

import Foundation

struct WeakRef<T: AnyObject> {
  weak var value: T?

  init(_ value: T) {
    self.value = value
  }
}
