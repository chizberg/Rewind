//
//  Identified.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 09.02.2025.
//

import SwiftUI

struct Identified<Value>: Identifiable, Hashable {
  let id: UUID = .init()
  let value: Value

  static func ==(lhs: Identified<Value>, rhs: Identified<Value>) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
