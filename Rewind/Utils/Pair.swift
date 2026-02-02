//
//  Pair.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 7. 12. 2025.
//

import Foundation

struct Pair<T, U> {
  let first: T
  let second: U

  init(_ first: T, _ second: U) {
    self.first = first
    self.second = second
  }
}

extension Pair: Equatable where T: Equatable, U: Equatable {}
