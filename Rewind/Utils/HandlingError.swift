//
//  HandlingError.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 20. 11. 2025.
//

import Foundation

struct HandlingError: Error, CustomStringConvertible {
  var description: String

  init(_ description: String) {
    self.description = description
  }
}
