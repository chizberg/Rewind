//
//  Either+Extensions.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 11. 2025..
//

import VGSL

extension Either {
  var left: T? {
    if case let .left(left) = self { left } else { nil }
  }

  var right: U? {
    if case let .right(right) = self { right } else { nil }
  }
}
