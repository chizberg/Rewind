//
//  Direction.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 15.01.2023.
//

import Foundation

enum Direction: String, Codable, Hashable {
  case n
  case e
  case s
  case w
  case ne
  case nw
  case se
  case sw

  case aero

  init?(_ s: String?) {
    guard let s, !s.isEmpty else { return nil }
    guard let dir = Direction(rawValue: s) else {
      assertionFailure("unknown direction")
      return nil
    }
    self = dir
  }
}

extension Direction {
  var angle: CGFloat? {
    switch self {
    case .n: return 0
    case .e: return .pi / 2
    case .s: return .pi
    case .w: return -.pi / 2
    case .ne: return .pi / 4
    case .nw: return -.pi / 4
    case .se: return .pi / 4 * 3
    case .sw: return -.pi / 4 * 3
    case .aero: return nil
    }
  }
}
