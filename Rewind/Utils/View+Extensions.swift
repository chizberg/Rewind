//
//  View+Extensions.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 06.02.2025.
//

import SwiftUI
import VGSL

extension View {
  func frame(size: CGSize) -> some View {
    frame(width: size.width, height: size.height)
  }

  func frame(squareSize: CGFloat) -> some View {
    frame(width: squareSize, height: squareSize)
  }

  func readFrame(
    in coordinateSpace: CoordinateSpace = .local,
    action: @escaping (CGRect) -> Void
  ) -> some View {
    onGeometryChange(
      for: CGRect.self,
      of: { $0.frame(in: coordinateSpace) },
      action: action
    )
  }

  func readSize(
    action: @escaping (CGSize) -> Void
  ) -> some View {
    readFrame { action($0.size) }
  }

  @ViewBuilder
  func `if`(
    _ condition: Bool,
    transform: (Self) -> some View,
    else elseTransform: (Self) -> some View
  ) -> some View {
    if condition {
      transform(self)
    } else {
      elseTransform(self)
    }
  }

  @ViewBuilder
  func `if`(
    _ condition: Bool,
    transform: (Self) -> some View
  ) -> some View {
    self.if(condition, transform: transform, else: { $0 })
  }
}

extension SwiftUI.ScrollView {
  func showsIndicators(_ shows: Bool) -> some View {
    modified(self) {
      $0.showsIndicators = shows
    }
  }
}
