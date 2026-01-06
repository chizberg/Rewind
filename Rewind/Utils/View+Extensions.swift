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
  func ifLet<T>(
    _ value: T?,
    transform: (Self, T) -> some View,
    else elseTransform: (Self) -> some View
  ) -> some View {
    if let value {
      transform(self, value)
    } else {
      elseTransform(self)
    }
  }

  func `if`(
    _ condition: Bool,
    transform: (Self) -> some View
  ) -> some View {
    self.if(condition, transform: transform, else: { $0 })
  }

  func ifLet<T>(
    _ value: T?,
    transform: (Self, T) -> some View
  ) -> some View {
    self.ifLet(value, transform: transform, else: { $0 })
  }

  func modify(
    @ViewBuilder transform: (Self) -> some View
  ) -> some View {
    transform(self)
  }

  @ViewBuilder
  func modifyWithUIIdiom(
    phone: (Self) -> some View,
    pad: (Self) -> some View
  ) -> some View {
    switch UIDevice.current.userInterfaceIdiom {
    case .phone: phone(self)
    case .pad: pad(self)
    default: phone(self)
    }
  }

  func modifyWithUIIdiom(
    _ idiom: UIUserInterfaceIdiom,
    transform: (Self) -> some View
  ) -> some View {
    self.if(
      UIDevice.current.userInterfaceIdiom == idiom,
      transform: transform
    )
  }

  func sheet(
    _ value: Binding<Identified<UIViewController>?>
  ) -> some View {
    sheet(
      item: value,
      content: { vc in
        ViewControllerRepresentable {
          vc.value
        }
      }
    )
  }
}

extension SwiftUI.ScrollView {
  func showsIndicators(_ shows: Bool) -> some View {
    modified(self) {
      $0.showsIndicators = shows
    }
  }
}
