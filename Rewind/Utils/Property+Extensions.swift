//
//  Property+Extensions.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 17.2.25..
//

import VGSL

extension Property {
  static func constant(_ value: T) -> Self {
    Property(getter: { value }, setter: { _ in })
  }
}
