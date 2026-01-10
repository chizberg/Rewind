//
//  ImageDate.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

struct ImageDate: Equatable, Codable, Hashable {
  var year: Int
  var year2: Int

  var description: String {
    guard year != year2 else { return String(year) }
    return "\(year) - \(year2)"
  }
}

extension ImageDate: Comparable {
  static func <(lhs: ImageDate, rhs: ImageDate) -> Bool {
    (lhs.year, lhs.year2) < (rhs.year, rhs.year2)
  }
}
