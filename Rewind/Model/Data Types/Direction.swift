//
//  Direction.swift
//  Camera Roll
//
//  Created by Alexey Sherstnev on 15.01.2023.
//

import Foundation

enum Direction: String, Codable, Hashable, CaseIterable {
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
    case .n: 0
    case .e: .pi / 2
    case .s: .pi
    case .w: -.pi / 2
    case .ne: .pi / 4
    case .nw: -.pi / 4
    case .se: .pi / 4 * 3
    case .sw: -.pi / 4 * 3
    case .aero: nil
    }
  }
}
