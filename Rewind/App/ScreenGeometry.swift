//
//  ScreenGeometry.swift
//  Rewind
//
//  Created by Aleksei Sherstnev on 18. 10. 2026.
//

import SwiftUI
import UIKit

@MainActor @Observable
final class ScreenGeometry {
  private(set) var size: CGSize
  private(set) var safeAreaInsets: UIEdgeInsets

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
  }
}

extension EnvironmentValues {
  @Entry
  var screenGeometry: ScreenGeometry?
}
