//
//  View+Extensions.swift
//  Rewind
//
//  Created by Alexey Sherstnev on 06.02.2025.
//

import SwiftUI

extension View {
  func frame(size: CGSize) -> some View {
    frame(width: size.width, height: size.height)
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
}
