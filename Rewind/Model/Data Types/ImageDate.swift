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
