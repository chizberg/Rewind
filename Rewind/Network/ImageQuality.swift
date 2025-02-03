//
//  ImageQuality.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 02.02.2025.
//

import Foundation

enum ImageQuality: Int {
  case low
  case medium
  case high

  var linkParam: String {
    switch self {
    case .low: return "s"
    case .medium: return "d"
    case .high: return "a"
    }
  }
}

extension ImageQuality: Comparable {
  static func <(lhs: ImageQuality, rhs: ImageQuality) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

