//
//  BlurEdge.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 09.02.2025.
//

import SwiftUI

// UNUSED, SHOULD PROBABLY BE REMOVED
extension View {
  func blur(
    edge: Edge,
    fraction: CGFloat = 0.1,
    scale: CGFloat = 1.3,
    radius: CGFloat = 20
  ) -> some View {
    modifier(BlurEdge(fraction: fraction, scale: scale, radius: radius, edge: edge))
  }

  @ViewBuilder
  fileprivate func offset(to edge: Edge, by value: CGFloat) -> some View {
    switch edge {
    case .top: offset(y: -value)
    case .leading: offset(x: -value)
    case .bottom: offset(y: value)
    case .trailing: offset(x: value)
    }
  }
}

extension SwiftUI.Alignment {
  fileprivate init(edge: Edge) {
    switch edge {
    case .top: self = .top
    case .leading: self = .leading
    case .bottom: self = .bottom
    case .trailing: self = .trailing
    }
  }
}

extension Edge {
  fileprivate var unitPoint: UnitPoint {
    switch self {
    case .top: return .top
    case .leading: return .leading
    case .bottom: return .bottom
    case .trailing: return .trailing
    }
  }

  fileprivate var opposite: Edge {
    switch self {
    case .top: return .bottom
    case .leading: return .trailing
    case .bottom: return .top
    case .trailing: return .leading
    }
  }
}

// overlays content with blurred copy at the edge
private struct BlurEdge: ViewModifier {
  var fraction: CGFloat
  var scale: CGFloat
  var radius: CGFloat
  var edge: Edge

  private let heightOf🩼: CGFloat = 200

  func body(content: Content) -> some View {
    content
      .overlay {
        content
          .blur(radius: radius)
          .mask {
            ZStack {
              Rectangle()
                .foregroundStyle(makeMaskGradient())
                .overlay(alignment: Alignment(edge: edge)) {
                  // 🩼 to show blur beyond bounds
                  Rectangle().fill(.white).frame(height: heightOf🩼)
                    .offset(to: edge, by: heightOf🩼 - 1)
                }
            }
          }
          .scaleEffect(scale)
      }
  }

  func makeMaskGradient() -> LinearGradient {
    // https://www.desmos.com/calculator/kdfqs6yuig
    // difference between scaled and unscaled image from one side
    let inset = (scale - 1) / 2
    // point where opacity is 1
    let opaquePoint = 1 - inset
    // point where opacity starts going from 0 to 1
    let opacityStartPoint = opaquePoint - fraction
    return LinearGradient(
      stops: [
        .init(color: .clear, location: 0),
        .init(color: .clear, location: opacityStartPoint),
        .init(color: .white, location: opaquePoint),
        .init(color: .white, location: 1)
      ],
      startPoint: edge.opposite.unitPoint,
      endPoint: edge.unitPoint
    )
  }
}
