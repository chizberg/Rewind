//
//  CGRect+Extensions.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 9. 2026.
//

import CoreGraphics

extension CGRect {
  func farthestCornerDistance(from point: CGPoint) -> Double {
    let corners = [
      CGPoint(x: minX, y: minY),
      CGPoint(x: maxX, y: minY),
      CGPoint(x: minX, y: maxY),
      CGPoint(x: maxX, y: maxY),
    ]
    return corners.reduce(0) { max($0, hypot($1.x - point.x, $1.y - point.y)) }
  }
}
