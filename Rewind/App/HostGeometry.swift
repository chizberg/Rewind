//
//  HostGeometry.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import SwiftUI
import UIKit

@MainActor @Observable
final class HostGeometry {
  private(set) var size: CGSize
  private(set) var safeAreaInsets: UIEdgeInsets
  private(set) var verticalBarEdge: Edge?

  init(size: CGSize, safeAreaInsets: UIEdgeInsets) {
    self.size = size
    self.safeAreaInsets = safeAreaInsets
  }

  func update(from view: UIView) {
    if size != view.bounds.size {
      size = view.bounds.size
    }
    if safeAreaInsets != view.safeAreaInsets {
      safeAreaInsets = view.safeAreaInsets
    }
    let verticalBarEdge = view.verticalBarEdge
    if self.verticalBarEdge != verticalBarEdge {
      self.verticalBarEdge = verticalBarEdge
    }
  }
}

extension UIView {
  fileprivate var verticalBarEdge: Edge? {
    #if canImport(UIKit, _version: 9127.0.85)
    guard #available(iOS 27.1, *) else { return nil }
    return switch traitCollection.verticalBarEdge {
    case .leading: .leading
    case .trailing: .trailing
    default: nil
    }
    #else
    return nil
    #endif
  }
}

extension EnvironmentValues {
  @Entry
  var hostGeometry: HostGeometry?
}
